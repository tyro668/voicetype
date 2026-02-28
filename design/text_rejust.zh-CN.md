# 文本重整与一致性保持策略

## 目标

在语音转文字的后处理链路中，确保长时间录音产出的文本具备：
1. **术语一致性** — 同一术语在全文中统一表达，不因 ASR 波动而漂移
2. **风格一致性** — 标点、大小写、语气在全文中保持稳定
3. **语义保真性** — 纠错与润色不引入原文没有的信息

## 范围与非目标

| 范围内 | 非目标 |
|--------|--------|
| 纠错阶段（`CorrectionService`）的上下文与术语策略 | 语音模型本身的准确率提升 |
| 增强阶段（`default_prompt.md`）的场景化风格控制 | 多语种混合翻译 |
| 终态回溯改写已上屏文本（MVP） | 实时流式中间结果的 UI 动画交互细节 |
| 会议链路与普通录音链路的一致性对齐 | 离线批量转写场景 |

---

## 关键术语

| 术语 | 含义 |
|------|------|
| `#R` | 参考词典（Reference），格式为 `错词->正词`，多组用 `\|` 分隔 |
| `#C` | 历史上下文（Context），前几段已纠错文本 |
| `#I` | 待纠错文本（Input），ASR 原始输出 |
| SessionGlossary | 会话级术语表，记录本次录音中已确认的同音字→术语映射（Phase 2） |

> 协议字段与 `lib/services/correction_service.dart` 中 `_buildUserMessage` 及 `assets/prompts/correction_prompt.md` 一致，均使用 `#R/#C/#I` 短标记。

---

## 策略设计

### 1. 滚动上下文滑动窗口（Sliding Context Window）

**问题**：每段 ASR 结果独立发给 LLM，模型丢失前文语义背景，术语判断不稳定。

**方案**：发送当前片段时，强制附带最近 N 段已纠错文本作为 `#C`。

- **已实现**：`CorrectionContext`（`lib/services/correction_context.dart`）维护最近 5 段滑动窗口，通过 `addSegment()` / `getContextString()` 管理。
- **Token 优化**：历史文本仅做语境参考，不重复附带字典。

**Prompt 协议示例**：

```
#R: 反软->帆软|美提斯->Metis
#C: 上一段已纠错的文本内容
#I: 当前待纠错的 ASR 原始输出
```

---

### 2. 会话级术语锚定（Session-Level Terminology Pinning）

**问题**：第一句正确纠错了"反软→帆软"，第二句因语境变化 LLM 回退为错误形式。

**分阶段实施**：

#### Phase 1（已具备）：词典 + 上下文窗口

- 词典（`#R`）提供静态映射，上下文窗口（`#C`）提供动态语境。
- 词典命中通过 `PinyinMatcher` 本地召回 + Top-K 评分裁剪（见 `correction_recall_strategy.zh-CN.md`）。
- 当前能力足以覆盖大部分场景。

#### Phase 2（待实现）：SessionGlossary 动态锚定

- 在 Dart 端维护 `SessionGlossary`（`Map<String, String>`），生命周期跟随录音会话。
- **锁定流程**：
  1. LLM 完成一次同音字修正（如 `反软 → 帆软`）
  2. Dart 端对比 `#I` 与纠错结果，提取新映射
  3. 映射存入 SessionGlossary，后续请求强制注入 `#R`
- **误锚定回退**：
  - SessionGlossary 条目附带置信度计数（出现次数）
  - 仅出现 1 次的映射标记为"弱锚定"，不强制注入
  - 用户可通过词典页手动纠正，立即覆盖 SessionGlossary
- **数据结构**：

```
SessionGlossary {
  entries: Map<String, TermPin>
}
TermPin {
  original: String       // 错词
  corrected: String      // 正词
  hitCount: int          // 命中计数
  firstSeenSegment: int  // 首次出现的段号
}
```

---

### 3. 场景化风格策略（Style & Formatting Anchor）

**问题**：纠错提示词（`correction_prompt.md`）要求"不改变语气和句式"，增强提示词（`default_prompt.md`）要求"删除语气词"，两者语义冲突。

**方案**：按场景切换风格目标，纠错阶段始终保真，润色阶段按模板分化。

| 场景 | 纠错阶段 | 增强阶段 |
|------|----------|----------|
| 普通输入 | 仅修正同音字，严格保真 | 轻度润色，保留口语特征与语气词 |
| 会议纪要 | 仅修正同音字，严格保真 | 删除语气词，更书面化，按语义分段 |

**实现映射**：
- 纠错阶段：统一使用 `assets/prompts/correction_prompt.md`（已落地）
- 增强阶段：根据场景加载不同模板
  - 普通：`template_colloquial.md` / `template_punctuation.md`
  - 会议：`template_meeting.md` / `template_formal.md`

**System Prompt 补充约束**：
1. 标点风格统一（全角符号）
2. 专有名词大小写保持（如 `Flutter` 而非 `flutter`）
3. 禁止新增原文没有的信息与观点

---

### 4. 终态回溯改写（Retrospective Refinement）

**问题**：实时纠错逐句处理，后文语义往往能修正前文的错误判断，但已上屏文本不会回头修改。

**方案（MVP）**：在段落结束时，将整段文本重新发给 LLM 做一次全段复核，并替换已上屏内容。

#### 触发条件

| 触发方式 | 说明 |
|----------|------|
| 静默检测 | 检测到 >= 1.5 秒静默，判定当前段落结束 |
| 手动结束 | 用户点击"停止录音"按钮 |
| 会议分段 | `SlidingWindowMerger` 产出合并段落时 |

#### 改写边界（MVP）

- **最小单元**：当前段落（从上次触发到本次触发之间的所有已纠错文本）
- **上下文注入**：附带前一段落作为 `#C`，不跨更多段落
- **不跨段回写**：仅替换当前段落的已上屏文本，不修改历史段落

#### 回写策略

- 普通录音链路：终态结果直接替换光标处已插入的文本
- 会议链路：终态结果写入 `transcription` 字段，增强基于终态结果而非 `rawText`

#### Pipeline

```
Level 1（实时）: ASR_Stream -> Debounce -> Local_Lookup -> LLM_Fast_Correct -> UI_Update
Level 2（终态）: Silence_Detected -> Collect_Paragraph -> LLM_Deep_Review -> UI_Replace
```

#### 当前实现差距

- 会议链路 `_processSegment` 中增强仍基于 `rawText` 而非纠错后文本（`lib/services/meeting_recording_service.dart`），需修正为以纠错结果作为增强输入。
- 静默检测触发终态回溯的调度逻辑尚未实现。

---

### 5. 工程实现建议

为保证一致性逻辑不拖慢 UI 响应：

- **CorrectionContext**（已有）：管理 `List<String>` 历史窗口，每次 `startRecording` 重置。
- **SessionGlossary**（待建）：管理 `Map<String, TermPin>` 会话术语，跟随录音会话生命周期。
- **Pipeline 统一**：普通录音链路（`RecordingProvider`）与会议链路（`MeetingRecordingService`）共用同一 CorrectionService 实例与配置参数，避免行为分叉。
- **增强输入源统一**：所有链路的增强阶段应以纠错后文本为输入，不再使用 `rawText`。

---

## 现状对照

| 策略 | 状态 | 关键文件 |
|------|------|----------|
| 滚动上下文窗口 | 已实现 | `lib/services/correction_context.dart` |
| `#R/#C/#I` 协议 | 已实现 | `lib/services/correction_service.dart`、`assets/prompts/correction_prompt.md` |
| 本地召回 + Top-K | 已实现 | `lib/services/pinyin_matcher.dart`、`lib/services/correction_service.dart` |
| 参数贯通（录音/会议/测试页） | 已实现 | `lib/providers/settings_provider.dart` |
| 场景化增强模板 | 已实现 | `assets/prompts/template_*.md` |
| SessionGlossary 术语锚定 | 未实现 | — |
| 终态回溯改写 | 未实现 | — |
| 增强输入源统一（纠错后文本） | 部分实现 | `lib/services/meeting_recording_service.dart` 会议链路待修正 |

---

## 测试与验收

### 功能测试

| 测试项 | 验证方法 | 通过标准 |
|--------|----------|----------|
| 术语跨段一致性 | 构造 5 段含同一术语的 ASR 输出，验证全文术语统一 | 同一术语 0 次漂移 |
| 场景风格切换 | 同一段口语分别用普通模板和会议模板增强，对比输出 | 普通模板保留语气词；会议模板删除语气词 |
| 终态回溯正确性 | 模拟静默触发，对比逐句纠错结果与全段复核结果 | 全段复核结果不劣于逐句结果 |
| 上下文窗口截断 | 连续输入 > 5 段，验证第 6 段的 `#C` 仅含最近 5 段 | `CorrectionContext._recentSegments.length <= 5` |
| 误锚定回退（Phase 2） | 注入一次错误映射，验证弱锚定不强制生效 | hitCount=1 的条目不出现在 `#R` 中 |

### 性能测试

| 指标 | 目标值 | 测量方式 |
|------|--------|----------|
| 实时纠错 P95 延迟 | <= 800ms | 从 ASR 回调到 UI 更新的端到端耗时 |
| 终态回溯耗时 | <= 3s（单段 <= 500 字） | 从触发到 UI 替换完成 |
| 单次纠错 token 成本 | `#R` <= 30 条，总 prompt <= 2000 token | 日志统计（已有 SQLite 指标表） |

### 回归测试

- 普通录音链路与会议链路：同一输入通过两条链路分别处理，纠错结果应一致。
- 提示词测试页（`prompt_workshop_page.dart`）：后处理强度不应高于主链路。

---

## 风险与回退

| 风险 | 影响 | 回退策略 |
|------|------|----------|
| 终态回溯导致已上屏文本跳变，用户体感差 | 中 | 配置开关，默认关闭；开启时用渐变动画过渡 |
| SessionGlossary 误锚定扩散 | 高 | 弱锚定机制 + 用户手动覆盖 + 会话结束自动清空 |
| 全段复核引入过度润色 | 中 | 终态回溯仅用纠错提示词，不走增强提示词 |
| Token 成本上升 | 低 | 终态回溯仅对当前段落，不累积历史段 |

---

## 实施里程碑

| 阶段 | 内容 | 前置条件 |
|------|------|----------|
| M1 | 增强输入源统一：会议链路增强改用纠错后文本 | 无 |
| M2 | 终态回溯 MVP：静默/手动触发 -> 全段复核 -> UI 替换 | M1 |
| M3 | SessionGlossary Phase 2：动态锚定 + 误锚定回退 | M1 |
| M4 | 性能调优：P95 延迟达标，token 成本可控 | M2 + M3 |
