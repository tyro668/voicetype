# 词典召回优化与本地统计（归档）

## 背景

词典规模增大后，如果把大量候选词直接拼进 `#R`，会导致纠错请求 token 显著上升。为降低成本并保持纠错质量，系统采用“本地优先筛选 + 小规模上云纠错”的策略。

---

## 已落地策略

### 1) 本地召回分层

- 先做字面匹配与拼音精确匹配；
- 拼音模糊匹配引入桶索引（按音节数+声母签名），避免全量遍历；
- 单字模糊匹配默认关闭，减少误召回。

文件：
- `lib/services/pinyin_matcher.dart`

### 2) 本地评分与 Top-K 裁剪

- 对命中条目做本地评分（字符相似度 + 拼音相似度 + 规则类型加权）；
- 设置 `minCandidateScore` 过滤低价值候选；
- 设置 `maxReferenceEntries` 限制 #R 条目上限；
- #R 构造做规则去重，减少重复映射。

文件：
- `lib/services/correction_service.dart`

### 3) 参数贯通

- 默认参数在设置层集中管理：
  - `correctionMaxReferenceEntries`
  - `correctionMinCandidateScore`
  - `correctionEnableSingleCharFuzzy`
- 参数已打通到录音链路、会议链路和提示词测试页。

文件：
- `lib/providers/settings_provider.dart`
- `lib/screens/main_screen.dart`
- `lib/providers/recording_provider.dart`
- `lib/providers/meeting_provider.dart`
- `lib/services/meeting_recording_service.dart`
- `lib/screens/pages/meeting_recording_page.dart`
- `lib/screens/pages/prompt_workshop_page.dart`

### 4) 录音链路纠错生效修复

- 修复了录音开始时误清空纠错服务的问题，确保主链路纠错配置持续生效。

文件：
- `lib/providers/recording_provider.dart`

---

## SQLite 指标持久化（新）

### 设计目的

将召回与 token 指标写入 SQLite（settings 表），支持后续阈值调优、策略回归和版本对比。

### 指标项

- `correction_calls_total`
- `correction_llm_calls_total`
- `correction_matches_total`
- `correction_selected_total`
- `correction_reference_chars_total`
- `correction_prompt_tokens_total`
- `correction_completion_tokens_total`

### 写入时机

在 `CorrectionService.correct()` 各分支统一记录：

1. 无命中（跳过 LLM）
2. 本地过滤后为空（跳过 LLM）
3. 调用 LLM 成功
4. 调用异常回退

### 实现文件

- `lib/services/correction_stats_service.dart`
- `lib/services/correction_service.dart`（调用接入）

---

## 预期收益

- 降低平均 #R 长度与 prompt token；
- 降低无效召回带来的 LLM 调用；
- 保持关键术语纠错能力；
- 建立可观测数据基础，支持持续调参。

---

## 测试句子与纠错样例

以下样例用于手工回归（提示词测试页）与自动化测试补充。

### A. 同音误写纠正（中文术语）

| 词典条目 | 输入句子 | 预期输出 |
|---|---|---|
| `兴阔 -> 星阔` | 兴阔今年发布了新产品。 | 星阔今年发布了新产品。 |
| `蓝乔 -> 蓝桥` | 蓝乔的报表系统很稳定。 | 蓝桥的报表系统很稳定。 |
| `云凡 -> 云帆` | 云凡平台支持实时同步。 | 云帆平台支持实时同步。 |

### B. 中文术语 + 拉丁别名（中文优先）

| 词典条目 | 输入句子 | 预期输出 |
|---|---|---|
| `星阔 -> XingKuo` | XingKuo 的数据中心上线了。 | 星阔的数据中心上线了。 |
| `星阔 -> XingKuo` | xing kuo 本周完成迁移。 | 星阔本周完成迁移。 |
| `星阔 -> XingKuo` | xing-kuo 报表性能提升明显。 | 星阔报表性能提升明显。 |

### C. 多词命中与 Top-K 裁剪

词典示例：`兴阔->星阔`、`蓝乔->蓝桥`、`云凡->云帆`、`云返->云帆`。

- 输入：`兴阔和蓝乔都在做云凡项目。`
- 预期：`星阔和蓝桥都在做云帆项目。`
- 验证点：
  - 只应召回必要词条（受 `maxReferenceEntries` 控制）；
  - 低分候选被 `minCandidateScore` 过滤；
  - 最终输出不应出现未命中的错误替换。

### D. 保留规则（Preserve）

| 词典条目 | 输入句子 | 预期输出 |
|---|---|---|
| `Metis`（preserve） | 今天在 Metis 上跑了任务。 | 今天在 Metis 上跑了任务。 |
| `OpenAPI`（preserve） | openapi 文档需要更新。 | OpenAPI 文档需要更新。 |

### E. 边界与容错场景

1. **无命中场景**  
  输入：`今天天气不错。`  
  预期：原样输出，不调用纠错 LLM。

2. **单字模糊误召回防护**（默认关闭单字模糊）  
  词典：`柯 -> 科`  
  输入：`库存充足。`  
  预期：不应因单字近音误召回而替换。

3. **纠错模型异常回退**  
  输入：`兴阔的数据很完整。`  
  预期：即使纠错模型失败，也应返回可用文本（不阻断主流程）。

4. **增强阶段反向改写防护**  
  输入：`星阔完成了交付。`（增强模型可能输出 `XingKuo`）  
  预期：最终结果保持中文术语 `星阔`。

### F. 更多边界回归样本（短词、同音多义、英文混排）

#### F1. 短词场景（防误召回）

1. **单字同声母噪声**（默认关闭单字模糊）  
  词典：`柯 -> 科`  
  输入：`库存还有多少？`  
  预期：`库存还有多少？`（不应把“库”误改为“科”）

2. **双字短词精准纠正**  
  词典：`蓝乔 -> 蓝桥`  
  输入：`蓝乔系统有告警。`  
  预期：`蓝桥系统有告警。`

3. **短词与长词冲突时长词优先**  
  词典：`云凡 -> 云帆`、`云凡平台 -> 云帆平台`  
  输入：`云凡平台正在升级。`  
  预期：`云帆平台正在升级。`（应优先命中长词规则）

#### F2. 同音多义场景（结合上下文）

1. **业务语境歧义**  
  词典：`蓝乔 -> 蓝桥`、`栏桥 -> 蓝桥`  
  输入：`请把蓝乔的数据看板发我。`  
  预期：`请把蓝桥的数据看板发我。`

2. **非业务语境避免过纠正**  
  词典：`蓝乔 -> 蓝桥`  
  输入：`公园里有一座蓝色的小桥。`  
  预期：原句保持不变（不应强行改成品牌词）

3. **多候选同音冲突**  
  词典：`兴阔 -> 星阔`、`新阔 -> 星阔`、`星扩 -> 星阔`  
  输入：`新阔这次的版本发布时间是什么时候？`  
  预期：`星阔这次的版本发布时间是什么时候？`

#### F3. 英文混排场景（中英文规范化）

1. **大小写归一**  
  词典：`OpenAPI`（preserve）  
  输入：`openapi 网关已经发布。`  
  预期：`OpenAPI 网关已经发布。`

2. **中英别名回写中文**  
  词典：`星阔 -> XingKuo`  
  输入：`XingKuo v2.1 昨晚已上线。`  
  预期：`星阔 v2.1 昨晚已上线。`

3. **英文缩写与中文术语共存**  
  词典：`SDK`（preserve）、`兴阔 -> 星阔`  
  输入：`xing kuo sdk 今天发版。`  
  预期：`星阔 SDK 今天发版。`

4. **连字符/空格别名形态**  
  词典：`星阔 -> XingKuo`  
  输入：`xing-kuo 和 xing kuo 的配置要一致。`  
  预期：`星阔和星阔的配置要一致。`

#### F4. 回归执行建议

- 每次调整 `maxReferenceEntries`、`minCandidateScore`、`enableSingleCharFuzzy` 后，至少回归以上 12 条样本；
- 记录每条样本的：命中词条数、入选词条数、#R 字符长度、是否调用 LLM、最终输出；
- 若出现“误改增加”或“漏改增加”，优先回退单字模糊与阈值，再逐步灰度。

---

## 后续建议

1. 增加统计面板（开发模式）查看召回与 token 数据；
2. 基于历史统计做自适应阈值（按场景/词典规模）；
3. 增加更多边界样本（短词、同音多义、英文混排）回归测试。
