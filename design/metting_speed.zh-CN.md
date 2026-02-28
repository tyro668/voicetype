# 会议总结加速方案（设计说明）

## 问题

当前会议结束（`stopMeeting()`）后，`MeetingProvider` 串行执行三步 LLM 调用：

```
stopMeeting()
  ├─ 等待所有分段 STT + 增强处理完成
  ├─ _polishMergedText()   ← 全量合并整理（LLM，timeout 120s）
  ├─ _generateSummary()    ← 会议总结生成（LLM，timeout 120s）
  └─ _generateTitle()      ← 标题生成（LLM，timeout 15s）
```

对于一场 30 分钟的会议（约 60 个分段、上万字文本），结束后用户需要等待：

| 阶段 | 预估耗时 | 说明 |
|------|----------|------|
| 等待剩余分段处理 | 5 ~ 15s | 最后一段 STT + 增强 |
| `_polishMergedText` | 15 ~ 60s | 全量文本发给 LLM 整理 |
| `_generateSummary` | 10 ~ 30s | 整理后文本再发给 LLM 总结 |
| `_generateTitle` | 3 ~ 8s | 截取前 1500 字生成标题 |
| **合计** | **33 ~ 113s** | 串行叠加，体感很慢 |

核心痛点：**全部工作集中在会议结束后才开始，三步串行执行，耗时线性叠加**。

---

## 目标

将会议结束后的等待时间从 **~1-2 分钟** 降低到 **< 10 秒**，同时保持输出质量不下降。

---

## 整体方案：录中增量 + 结束并行

核心思路：**将尽可能多的工作前移到录音过程中完成，结束时仅做轻量收尾**。

```
录音过程中（后台增量）：
  ├─ SlidingWindowMerger 已实现 → 产出"实时合并纪要"
  ├─ 新增：IncrementalSummaryService → 增量更新摘要
  └─ 新增：AutoTitleService → 在前几段完成后自动生成标题

会议结束时（并行收尾）：
  ├─ 等待最后一段处理完成
  ├─ 决策：复用合并纪要 or 增量修补
  ├─ 并行：更新摘要 + 确认标题（如需要）
  └─ 持久化
```

### 结束时的时间线对比

```
【现在 — 串行】
 stopMeeting ──▶ waitSegments ──▶ polishAll ──▶ summary ──▶ title ──▶ done
                   ~10s            ~40s          ~20s        ~5s
                                                            总计 ~75s

【优化后 — 增量 + 并行】
 stopMeeting ──▶ waitLastSegment ──▶ ┬─ deltaPolish ──▶ done
                    ~5s               ├─ deltaSummary     总计 ~8s
                                      └─ confirmTitle
                                         并行 ~3s
```

---

## 详细设计

### 策略一：复用 SlidingWindowMerger 输出，消除全量 Polish

#### 现状

`SlidingWindowMerger` 在录音过程中已经以滑动窗口方式对分段文本进行了 AI 合并整理，产出 `MergedNote`。但 `stopMeeting()` 完全没有利用这些中间成果，而是重新把全量原始分段文本拼接后再调一次 LLM。

#### 改进方案

引入 **"增量拼接 + 尾部修补"** 模式，取代全量重新 Polish。

##### 1. 合并纪要缓存

在 `SlidingWindowMerger` 中维护一个有序的已合并文本缓存：

```dart
class SlidingWindowMerger {
  // 新增：按分段范围缓存每次合并产出的文本
  final List<MergedNote> _mergedNotes = [];

  // 新增：最新的完整合并文稿（各 MergedNote 去重拼接）
  String get currentFullText => _buildFullText();
}
```

每次 `_executeMerge` 完成后，将 `MergedNote` 追加到缓存。由于窗口有重叠，需要按 `segmentIndex` 去重拼接：

```
窗口1: [seg0..seg4] → mergedNote1
窗口2: [seg3..seg7] → mergedNote2  ← seg3/seg4 与窗口1重叠
窗口3: [seg6..seg10] → mergedNote3
```

拼接规则：**取每个窗口中非重叠部分**，即每个新窗口只贡献 `startSegmentIndex > 上一个 endSegmentIndex` 的增量部分。简化实现：直接取最后一次合并的完整文本作为 `currentFullText`（因为窗口滑动时后面的合并已包含前面的上下文）。

更精确的做法是使用 "分块覆盖" 策略：

```dart
String _buildFullText() {
  if (_mergedNotes.isEmpty) return '';

  // 按 startSegmentIndex 排序
  final sorted = List<MergedNote>.from(_mergedNotes)
    ..sort((a, b) => a.startSegmentIndex.compareTo(b.startSegmentIndex));

  // 取非重叠的最优覆盖：贪心选取覆盖范围最大的 note
  final selected = <MergedNote>[];
  int coveredUpTo = -1;

  for (final note in sorted) {
    if (note.endSegmentIndex > coveredUpTo) {
      selected.add(note);
      coveredUpTo = note.endSegmentIndex;
    }
  }

  return selected.map((n) => n.content).join('\n\n');
}
```

##### 2. 结束时增量修补

```dart
Future<MeetingRecord> stopMeeting() async {
  // ... 停止录音、等待最后分段 ...

  // 1. 获取 Merger 已产出的合并文稿
  final mergerText = _merger?.currentFullText ?? '';

  // 2. 检查是否有"尾部未覆盖"的分段
  //    （最后几段可能在 merger 最后一次触发后才完成 STT）
  final allSegments = await db.getMeetingSegments(meeting.id);
  final lastMergedIdx = _merger?.lastCoveredSegmentIndex ?? -1;
  final tailSegments = allSegments
      .where((s) => s.segmentIndex > lastMergedIdx
                  && s.transcription?.trim().isNotEmpty == true)
      .toList();

  String fullTranscription;
  if (tailSegments.isEmpty) {
    // 全部已被合并器覆盖，直接复用
    fullTranscription = mergerText;
  } else {
    // 仅对尾部未覆盖的分段做一次增量 Polish
    final tailText = tailSegments
        .map((s) => s.enhancedText ?? s.transcription ?? '')
        .join('\n');
    final polishedTail = await _polishMergedText(tailText); // 仅修补尾部
    fullTranscription = '$mergerText\n\n$polishedTail';
  }

  meeting.fullTranscription = fullTranscription;
}
```

**效果**：在大多数情况下，结束时 `polishMergedText` 要么完全跳过，要么只处理最后 1-2 段的少量文本（~几百字），从 40s 降到 0-3s。

---

### 策略二：增量摘要（Incremental Summary）

#### 现状

`_generateSummary()` 在会议结束后才执行，将完整文稿一次性发给 LLM 生成摘要。

#### 改进方案：录中递进式摘要

引入 `IncrementalSummaryService`，在录音过程中随着合并纪要的更新，递进地维护一份"运行中摘要"。

##### 核心思想：摘要滚动更新

```
每次 MergedNote 更新时：
  prompt = """
  以下是目前的会议摘要：
  {currentSummary}

  以下是新增的会议内容：
  {newContent}

  请更新会议摘要，整合新增内容。保持格式：
  1. 会议主题
  2. 关键讨论点
  3. 决议/行动项
  4. 待跟进事项
  """
```

```dart
class IncrementalSummaryService {
  String _currentSummary = '';
  String get currentSummary => _currentSummary;

  final AiEnhanceConfig _aiConfig;
  int _lastProcessedSegmentIndex = -1;
  bool _isUpdating = false;

  /// 触发频率控制：不是每次 MergedNote 都触发，
  /// 而是按间隔（如每 3 次合并、或每 2 分钟）触发一次增量更新。
  int _mergeCountSinceLastUpdate = 0;
  static const int _updateInterval = 3; // 每 3 次合并触发一次

  /// 当合并纪要有新产出时调用
  Future<void> onMergeCompleted(MergedNote note, String fullMergedText) async {
    _mergeCountSinceLastUpdate++;
    if (_mergeCountSinceLastUpdate < _updateInterval) return;
    if (_isUpdating) return; // 防止并发

    _isUpdating = true;
    _mergeCountSinceLastUpdate = 0;

    try {
      if (_currentSummary.isEmpty) {
        // 首次生成：直接用全文生成摘要
        _currentSummary = await _generateFreshSummary(fullMergedText);
      } else {
        // 增量更新：传入当前摘要 + 新内容
        _currentSummary = await _updateSummary(
          _currentSummary,
          fullMergedText,
        );
      }
      _lastProcessedSegmentIndex = note.endSegmentIndex;
    } finally {
      _isUpdating = false;
    }
  }
}
```

##### 结束时处理

```dart
// 会议结束时
final incrementalSummary = _incrementalSummaryService?.currentSummary ?? '';

if (incrementalSummary.isNotEmpty) {
  // 如果有尾部增量文本，做一次最终更新
  if (tailText.isNotEmpty) {
    meeting.summary = await _incrementalSummaryService!
        .finalUpdate(incrementalSummary, tailText);
  } else {
    meeting.summary = incrementalSummary;
  }
} else {
  // fallback：降级为原来的全量生成
  meeting.summary = await _generateSummary(fullTranscription);
}
```

**效果**：会议结束时 summary 已经有了 90%+ 的内容，最多做一次增量更新（处理最后几段新内容），从 20s 降到 0-3s。

---

### 策略三：提前生成标题

#### 现状

标题在会议结束后，基于全部内容生成。

#### 改进方案

当前 5 段（约 2-3 分钟）STT 完成后即可触发标题生成——会议主题通常在开头就已确定。

```dart
// 在 _processSegment 完成回调中
if (_segmentIndex == 5 && _isDefaultTitle(meeting.title)) {
  unawaited(_generateEarlyTitle());
}
```

**结束时**：如果标题已生成则跳过，否则降级同步生成。从 5s 降到 0s。

---

### 策略四：结束收尾任务并行化

即使在需要做收尾工作的场景下，三个任务也应该并行执行：

```dart
Future<MeetingRecord> stopMeeting() async {
  // ... 停止录音，获取 mergerText 和 tailText ...

  // 并行执行所有收尾任务
  final results = await Future.wait([
    _finishPolish(mergerText, tailSegments),    // 增量修补
    _finishSummary(mergerText, tailText),        // 增量摘要
    _finishTitle(meeting),                       // 确认标题
  ]);

  meeting.fullTranscription = results[0] as String;
  meeting.summary = results[1] as String;
  meeting.title = results[2] as String;

  await db.updateMeeting(meeting);
}
```

**效果**：即使三项都需要做，也从串行 `40+20+5 = 65s` 降到并行 `max(3, 3, 0) ≈ 3s`。

---

## 涉及改动的模块

### 1. `SlidingWindowMerger` — 增加合并文稿缓存

| 改动 | 说明 |
|------|------|
| 新增 `_mergedNotes` 列表 | 缓存每次合并产出的 `MergedNote` |
| 新增 `currentFullText` getter | 对缓存做去重拼接，返回当前最优合并文稿 |
| 新增 `lastCoveredSegmentIndex` getter | 返回已覆盖到的最大分段索引 |
| `onSegmentCompleted` 中追加缓存 | 合并完成后同步写入缓存 |

### 2. `IncrementalSummaryService` — 新增

| 内容 | 说明 |
|------|------|
| 增量摘要 prompt | 基于 `meeting_summary_prompt.md` 扩展，支持"当前摘要 + 新内容"模式 |
| 频率控制 | 每 N 次合并触发一次，避免过度调用 |
| `finalUpdate()` | 结束时做最后一次更新 |
| Token 统计 | 纳入 `TokenStatsService` |

### 3. `MeetingRecordingService` — 集成增量服务

| 改动 | 说明 |
|------|------|
| 新增持有 `IncrementalSummaryService` 实例 | 随会议创建/销毁 |
| `_notifyMerger()` 后触发增量摘要 | 监听 `merger.onMergeCompleted`，转发给增量摘要服务 |
| 新增 `currentFullText` / `currentSummary` 暴露 | 供 `MeetingProvider` 使用 |

### 4. `MeetingProvider.stopMeeting()` — 重构收尾流程

| 改动 | 说明 |
|------|------|
| 复用合并纪要 | 不再全量 re-polish |
| 复用增量摘要 | 仅做尾部增量更新 |
| 并行执行收尾 | `Future.wait` 并行处理 polish/summary/title |
| 提前标题生成 | 结束时检查跳过 |

### 5. Prompt 新增/修改

| 文件 | 说明 |
|------|------|
| `meeting_incremental_summary_prompt.md`（新增） | 增量摘要更新 prompt |
| `meeting_summary_prompt.md` | 无变更，首次全量摘要仍复用 |
| `meeting_merge_prompt.md` | 无变更 |

---

## 增量摘要提示词设计

新增 `assets/prompts/meeting_incremental_summary_prompt.md`：

```markdown
你是会议记录助手。请根据当前的会议摘要和新增内容，更新会议摘要。

## 当前摘要
{current_summary}

## 新增会议内容
{new_content}

## 输出格式
1. **会议主题**：一句话概括（如主题有变化则更新）
2. **关键讨论点**：整合新旧要点列表
3. **决议/行动项**：如有，列出具体责任人和时间节点
4. **待跟进事项**：如有

## 要求
- 整合新旧内容，而非简单追加
- 删除已被后续讨论推翻的旧结论
- 保持简洁，只提取关键信息
- 忽略寒暄和无关内容
```

---

## 降级与容错

| 场景 | 降级策略 |
|------|----------|
| 增量摘要服务异常 | 回退到当前全量方式 |
| 合并纪要缓存为空（合并器未启用） | 回退到当前全量 polish |
| 增量 LLM 调用超时 | 使用最后一次成功的增量结果 |
| 尾部修补失败 | 直接拼接原始分段文本 |

所有新增逻辑均以"增强"方式叠加，**不改变现有回退路径**，确保基础功能不受影响。

---

## 预估收益

| 会议时长 | 当前等待 | 优化后等待 | 加速比 |
|----------|----------|------------|--------|
| 10 分钟 | ~30s | ~3s | **10x** |
| 30 分钟 | ~75s | ~5s | **15x** |
| 60 分钟 | ~120s | ~8s | **15x** |
| 2 小时 | ~180s+ | ~10s | **18x** |

> 会议越长，优化效果越显著。因为录音过程中有充足时间完成增量处理，结束时只需处理最后一个窗口的增量。

---

## Token 消耗分析

增量方案会在录音过程中产生额外的 LLM 调用，需要评估 token 消耗变化：

| 项目 | 当前方案 | 增量方案 | 变化 |
|------|----------|----------|------|
| 分段增强 | N 次 | N 次 | 不变 |
| 滑动窗口合并 | N 次 | N 次 | 不变（已有） |
| 全量 Polish | 1 次（全量文本） | 0-1 次（仅尾部） | **大幅减少** |
| 摘要生成 | 1 次（全量文本） | ~N/3 次（增量） | 输入更小，总量相近 |
| 标题生成 | 1 次 | 1 次（提前） | 不变 |

增量摘要虽然调用次数增多，但每次输入仅包含"当前摘要（几百字）+ 新增内容（几千字）"，远小于全量文本，总 token 消耗基本持平甚至略有下降。

---

## 界面适配设计

后端从"结束后串行处理"变为"录中增量处理"，前端界面需要同步适配，让用户在录音过程中就能感知到增量产出的成果，结束时实现"无缝过渡"。

### 当前界面结构

#### 录制页面（`MeetingRecordingPage`）

- **双视图切换**：分段视图 / 合并纪要视图（`_showMergedView` 切换）
- **分段视图**：`ListView` 逐段展示，每段一个 Card，显示时间戳 + 转写/增强文本 + 处理状态
- **合并纪要视图**：展示 `SlidingWindowMerger` 流式产出的合并文本（`mergedNoteContent`）
- **AppBar**：标题输入框 + 暂停/继续 + 停止按钮 + 录音时长

#### 详情页面（`MeetingDetailPage`）

- **Header**：标题（双击编辑）+ 日期 + 时长 + 字数 + 操作菜单
- **摘要面板**（可折叠）：只读展示 `meeting.summary`，支持重新生成
- **完整文稿面板**（可折叠）：展示 `meeting.fullTranscription`，支持编辑保存

### 界面改动方案

#### 1. 录制页面 — 新增实时摘要 Tab

##### 改为三视图切换

```
切换栏：[ 分段视图 ] [ 合并纪要 ] [ 实时摘要 ]
```

| Tab | 内容 | 数据来源 |
|-----|------|----------|
| 分段视图 | 保持不变，逐段展示 | `currentSegments` |
| 合并纪要 | 保持不变，流式合并文本 | `mergedNoteContent` |
| 实时摘要（新增） | 展示增量摘要的实时结果 | `IncrementalSummaryService.currentSummary` |

为什么新增而非替换：
- 分段视图用于调试 / 确认每段是否正确
- 合并纪要用于阅读连贯文稿
- 实时摘要用于快速了解会议进展——这三个场景不同

##### 实时摘要视图 UI

```dart
Widget _buildLiveSummaryArea(MeetingProvider provider, AppLocalizations l10n) {
  final summary = provider.incrementalSummary; // 新增属性
  final isUpdating = provider.isUpdatingIncrementalSummary; // 新增属性

  if (summary.isEmpty && !isUpdating) {
    return Center(
      child: Text(
        '会议进行中，摘要将在几分钟后开始生成…',
        style: TextStyle(fontSize: 14, color: _cs.outline),
      ),
    );
  }

  return SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isUpdating)
          // 更新中指示器
          _buildUpdatingIndicator(l10n),
        SelectableText(
          summary,
          style: TextStyle(fontSize: 14, color: _cs.onSurface, height: 1.6),
        ),
      ],
    ),
  );
}
```

##### 自动标题实时回显

当 `AutoTitleService` 在前 5 段后生成标题时，自动更新 `_titleController`：

```dart
// MeetingProvider 中
void _onAutoTitleGenerated(String title) {
  // 仅当标题仍是默认标题时替换
  if (_isDefaultTitle(currentMeeting?.title ?? '')) {
    currentMeeting?.title = title;
    notifyListeners(); // 触发 UI 刷新
  }
}
```

录制页面监听变化：

```dart
// 在 build() 中
if (provider.currentMeeting != null &&
    _titleController.text != provider.currentMeeting!.title) {
  _titleController.text = provider.currentMeeting!.title;
}
```

#### 2. 录制页面 — 默认视图切换为合并纪要

当前 `_showMergedView` 默认 `false`（分段视图）。优化后：

- **初始默认**：合并纪要视图（更贴近最终产出）
- 当合并纪要为空时（刚开始录音，前 1-2 段还没触发 Merger），自动回退展示分段视图
- 用户手动切换后锁定选择，不再自动切换

```dart
// 状态变量更新
bool _showMergedView = true;        // 默认改为 true
bool _userExplicitlyToggled = false; // 记录用户是否手动切过

// 视图切换逻辑
Widget _buildContentArea(...) {
  // 如果用户没手动切过，且合并纪要为空，自动回退到分段视图
  final effectiveShowMerged = _userExplicitlyToggled
      ? _showMergedView
      : (_showMergedView && provider.mergedNoteContent.isNotEmpty);

  return effectiveShowMerged
      ? _buildMergedNoteArea(provider, l10n)
      : _buildTranscriptionArea(segments, provider, l10n);
}
```

#### 3. 结束过渡 — 消除等待黑屏

##### 当前行为

```
用户点击停止 → 弹出全屏 loading → 等待 1-2 分钟 → 跳转到详情页
```

实际流程是 `_confirmEndMeeting()` 调用 `provider.stopMeeting()` await 完成后 `Navigator.pop(context)`，期间UI卡在录制页面的 `processing` 状态。

##### 优化后行为

```
用户点击停止 → 即时跳转到详情页（已有内容立即展示）→ 尾部内容在后台补全
```

**实现思路**：`stopMeeting()` 拆分为两步：

```dart
// MeetingProvider 新增
Future<MeetingRecord> stopMeetingFast() async {
  // Step 1：立即停止录音、保存当前增量成果
  final meeting = await _recordingService.stopRecording(); // 仅停录音
  
  // 立即将已有增量成果写入 meeting
  meeting.fullTranscription = _recordingService.merger?.currentFullText ?? '';
  meeting.summary = _incrementalSummaryService?.currentSummary ?? '';
  meeting.status = MeetingStatus.completed;
  await AppDatabase.instance.updateMeeting(meeting);
  
  return meeting; // 立即返回，UI 可以跳转
}

Future<void> finalizeMeetingInBackground(String meetingId) async {
  // Step 2：后台完成尾部收尾（增量修补 + 摘要更新 + 标题确认）
  // 完成后更新数据库，通知 UI 刷新
}
```

录制页面：

```dart
Future<void> _confirmEndMeeting() async {
  final provider = context.read<MeetingProvider>();
  
  // 快速停止，立即获得结果
  final meeting = await provider.stopMeetingFast();
  
  // 启动后台收尾（不 await）
  unawaited(provider.finalizeMeetingInBackground(meeting.id));
  
  // 立即跳转到详情页
  if (mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingDetailPage(meetingId: meeting.id),
      ),
    );
  }
}
```

#### 4. 详情页 — 后台更新感知

##### 新增"更新中"状态指示

当后台收尾任务还在运行时，详情页需要感知并展示：

```
┌─────────────────────────────────────────┐
│ 📋 会议摘要                    [正在完善…] │
│ ─────────────────────────────────────── │
│ 1. 会议主题：xxx                         │
│ 2. 关键讨论点：                           │
│    - xxx                                │
│    - xxx                                │
│ （尾部内容更新中…）                        │
└─────────────────────────────────────────┘
```

```dart
// MeetingProvider 新增状态
bool _isFinalizingMeeting = false;
bool get isFinalizingMeeting => _isFinalizingMeeting;

// 详情页感知
Widget _buildSummaryActions(AppLocalizations l10n) {
  final provider = context.watch<MeetingProvider>();
  
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (provider.isFinalizingMeeting)
        // 显示"完善中"标签
        _buildFinalizingBadge(l10n),
      _buildRegenerateSummaryButton(l10n),
      _buildSummaryCollapseButton(),
    ],
  );
}
```

##### 内容热更新

后台收尾完成后，详情页应自动刷新内容，而非需要用户手动重新进入：

```dart
// MeetingDetailPage 监听 MeetingProvider 变化
@override
Widget build(BuildContext context) {
  // 通过 watch 自动监听 notifyListeners
  final provider = context.watch<MeetingProvider>();
  
  // 当后台更新完成时，自动刷新本地数据
  if (!provider.isFinalizingMeeting && _meeting != null) {
    _refreshIfNeeded(provider);
  }
  // ...
}

void _refreshIfNeeded(MeetingProvider provider) {
  final updated = provider.meetings
      .where((m) => m.id == widget.meetingId)
      .firstOrNull;
  if (updated != null && updated.updatedAt != _meeting!.updatedAt) {
    setState(() {
      _meeting = updated;
      _detailController.text = updated.fullTranscription ?? '';
      _summaryController.text = updated.summary ?? '';
    });
  }
}
```

#### 5. 分段视图优化 — 连续文本流模式

##### 当前问题

分段视图每 20-30 秒一个 Card，每段边界有明显视觉分割。对于长会议（2 小时 = ~240 段），Card 列表很长且碎片化，不利于阅读。

##### 优化方案：连续文本流 + 时间锚点

替换逐段 Card 为一个连续滚动的文本区域，仅在关键位置插入轻量时间锚点：

```
13:24  会议开始，主要讨论了下季度的产品规划方向，
       重点包括 AI 功能集成和移动端优化……

13:26  张总提出了关于性能优化的几个建议，包括
       减少冷启动时间和优化数据库查询……
       ← 正在转写…

13:27  [●] 录音中
```

```dart
Widget _buildContinuousTranscription(
  List<MeetingSegment> segments,
  MeetingProvider provider,
  AppLocalizations l10n,
) {
  return SingleChildScrollView(
    controller: _scrollController,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          // 每 N 段或话题切换时插入时间锚点
          if (_shouldShowTimestamp(segments, i))
            _buildTimeAnchor(segments[i]),
          // 文本内容（无 Card 边框，连续排列）
          _buildSegmentText(segments[i]),
        ],
        // 正在录音指示器
        if (provider.isRecording && !provider.isPaused)
          _buildRecordingIndicator(l10n),
      ],
    ),
  );
}

bool _shouldShowTimestamp(List<MeetingSegment> segments, int index) {
  if (index == 0) return true;
  // 每 3 段显示一次时间戳（约每 1-1.5 分钟）
  return index % 3 == 0;
}

Widget _buildTimeAnchor(MeetingSegment segment) {
  return Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      segment.formattedTimestamp,
      style: TextStyle(
        fontSize: 11,
        color: _cs.outline,
        fontFamily: 'monospace',
      ),
    ),
  );
}

Widget _buildSegmentText(MeetingSegment segment) {
  // 处理中的段用淡色 + 加载指示器
  if (segment.status == SegmentStatus.transcribing ||
      segment.status == SegmentStatus.pending) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: 8),
          Text('转写中…', style: TextStyle(color: _cs.outline, fontSize: 13)),
        ],
      ),
    );
  }

  final text = (segment.enhancedText ?? segment.transcription ?? '').trim();
  if (text.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: SelectableText(
      text,
      style: TextStyle(fontSize: 14, color: _cs.onSurface, height: 1.6),
    ),
  );
}
```

### 涉及改动的 UI 文件

| 文件 | 改动 | 优先级 |
|------|------|--------|
| `meeting_recording_page.dart` | 新增"实时摘要"Tab；默认切为合并纪要视图；`stopMeeting` 拆分为快速停止 + 后台收尾；分段视图改为连续文本流 | P0/P1 |
| `meeting_detail_page.dart` | 新增"完善中"状态指示；内容热更新（watch provider 变化自动刷新） | P0 |
| `meeting_provider.dart` | 新增 `stopMeetingFast()` + `finalizeMeetingInBackground()`；暴露 `incrementalSummary` / `isFinalizingMeeting` 等状态 | P0 |
| `app_localizations` (l10n) | 新增国际化字符串：实时摘要 Tab 标签、"完善中"状态提示、连续文本流空状态等 | P1 |

### UI 改动与后端策略的对应关系

```
后端策略                          UI 适配
─────────────────────────────────────────────────────────────
策略一：复用 Merger 输出     →    默认展示合并纪要视图
                                  结束时直接复用已有文稿
策略二：增量摘要            →    新增"实时摘要"Tab
                                  详情页即时展示已有摘要
策略三：提前生成标题         →    录制时标题自动回显
策略四：结束并行化          →    stopMeetingFast 即时跳转
                                  后台收尾 + 详情页热更新
```

---

## 实现优先级

| 优先级 | 策略 | 效果 | 复杂度 |
|--------|------|------|--------|
| **P0** | 复用 Merger 输出 + 消除全量 Polish | 省去最耗时的步骤 | 低 |
| **P0** | 结束收尾任务并行化 | 立竿见影，改动极小 | 低 |
| **P0** | 结束即时跳转 + 详情页热更新 | 消除等待黑屏，体验质变 | 中 |
| **P1** | 增量摘要 + 实时摘要 Tab | 消除结束时总结等待 | 中 |
| **P1** | 分段视图改连续文本流 | 长会议阅读体验优化 | 中 |
| **P2** | 提前生成标题 + 实时回显 | 锦上添花 | 低 |
