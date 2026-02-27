# 会议录音智能分段策略（设计说明）

## 问题

当前会议录音服务（`MeetingRecordingService`）使用固定 30 秒 `Timer.periodic` 硬截断分段。这会导致：

- 一个正在说的词语/句子被拆分到两段录音中
- STT 转写在分段边界处丢字、断句不自然
- 上下文割裂影响后续纠错和增强效果

## 目标

在 **20 ~ 30 秒** 区间内寻找停顿（静音），在自然断句处截断，既保证每段时长合理，又避免"切词"问题。

---

## 整体方案

### 时间窗口模型

```
0s          20s                    30s
│───────────┼──────────────────────┤
│  安全期    │     柔性截断窗口      │ 强制截断
│ (不截断)   │ (检测到停顿即截断)    │
```

- **安全期（0 ~ `softMinSeconds`）** ：无论振幅如何，都不截断。  
- **柔性截断窗口（`softMinSeconds` ~ `hardMaxSeconds`）** ：进入振幅监听模式，一旦检测到 **连续 N 毫秒** 的静音（振幅 < 阈值），立刻截断当前段并开启下一段。  
- **强制截断（`hardMaxSeconds`）** ：到达硬上限后无论是否处于静音，立即截断。

### 核心参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `softMinSeconds` | 20 | 最短录音时长，之后才可被静音截断 |
| `hardMaxSeconds` | 30 | 最长录音时长，到时强制截断 |
| `silenceThresholdDb` | 0.05 | 归一化振幅阈值（0.0 ~ 1.0），低于此值视为静音 |
| `silenceDurationMs` | 500 | 持续静音时长（毫秒），达到后触发截断 |

---

## 涉及改动的模块

### 1. `VadService` — 增强为可复用的静音检测引擎

**现状**：`VadService` 已实现基础的振幅 → 静音检测逻辑，但仅暴露 `onSilenceDetected` 事件流、参数固定。

**改动内容**：

- 无需结构性改动，`VadService` 本身逻辑已满足需求
- 在 `MeetingRecordingService` 中实例化 `VadService` 时传入合适参数即可：
  - `silenceThreshold = 0.05`
  - `silenceDuration = Duration(milliseconds: 500)` （缩短到 500ms，更灵敏）
  - `minRecordingDuration = Duration(seconds: 20)` （20 秒后才可触发）

### 2. `MeetingRecordingService` — 替换简单 Timer 为智能分段控制器

**现状**：使用 `Timer.periodic(Duration(seconds: segmentDurationSeconds), ...)` 固定周期截断。

**改动内容**：

#### 2.1 新增成员变量

```dart
/// VAD 静音检测服务
VadService? _vadService;
StreamSubscription<void>? _vadSubscription;

/// 硬截断计时器（到 hardMaxSeconds 强制截断）
Timer? _hardCutTimer;

/// 当前分段开始时间（用于计算段时长）
DateTime? _segmentStartTime;

/// 智能分段参数
int softMinSeconds = 20;
int hardMaxSeconds = 30;
double silenceThreshold = 0.05;
int silenceDurationMs = 500;
```

#### 2.2 替换 `_segmentTimer` 逻辑

删除原来的 `Timer.periodic` 分段计时器，替换为以下流程：

**每个分段开始时（`_startSegmentRecording` 后）**：

```
1. 记录 _segmentStartTime = DateTime.now()
2. 创建 VadService 实例（参数如上）
3. 绑定 _vadSubscription 监听 onSilenceDetected
   → 触发时执行 _handleSilenceDetected()
4. 启动 VadService.start(_recorder.amplitudeStream)
5. 设置 _hardCutTimer = Timer(hardMaxSeconds, _handleHardCut)
```

**当 VAD 检测到静音时（`_handleSilenceDetected`）**：

```
1. 取消 _hardCutTimer
2. 停止 VAD
3. 执行 _finalizeCurrentSegment()
4. 启动下一段 _startSegmentRecording()
```

**当到达硬上限时（`_handleHardCut`）**：

```
1. 停止 VAD
2. 执行 _finalizeCurrentSegment()  
3. 启动下一段 _startSegmentRecording()
```

#### 2.3 修正分段元数据

当前 `_finalizeCurrentSegment` 中的分段 `startTime` 和 `duration` 使用固定的 `segmentDurationSeconds` 计算，改为基于实际时间：

```dart
final actualDuration = DateTime.now().difference(_segmentStartTime!);
final segment = MeetingSegment(
  ...
  startTime: _segmentStartTime!,
  duration: actualDuration,
  ...
);
```

#### 2.4 暂停/恢复处理

- `pause()`：停止 VAD、取消 `_hardCutTimer`、保存当前段
- `resume()`：开启新段时重新创建 VAD 和硬截断计时器

#### 2.5 `startMeeting` 参数扩展

```dart
Future<MeetingRecord> startMeeting({
  ...
  int softMinSeconds = 20,
  int hardMaxSeconds = 30,
  double silenceThreshold = 0.05,
  int silenceDurationMs = 500,
}) async { ... }
```

保持向后兼容：如果外部传入 `segmentSeconds`，则回退到原有固定截断模式（不启用智能分段）。

### 3. `MeetingProvider` — 透传新参数

在 `startMeeting` 调用中增加智能分段参数透传，目前使用默认值即可。

---

## 状态机

```
┌───────────────────────────────────┐
│            RECORDING              │
│                                   │
│  t=0: 开始录音, 启动 VAD + Timer  │
│  │                                │
│  │ 0s < t < 20s                   │
│  │  → VAD 监听中但 minDuration    │
│  │    限制不会触发                 │
│  │                                │
│  │ 20s ≤ t < 30s                  │
│  │  → VAD 可触发                  │
│  │  → 检测到停顿 → 柔性截断 ──────┼──→ 保存段 → 开始新段
│  │                                │
│  │ t = 30s                        │
│  │  → 硬截断计时器触发 ───────────┼──→ 保存段 → 开始新段
│  │                                │
│  ▼                                │
│  [暂停] → 停止 VAD + Timer        │
│  [恢复] → 新段 + 重新启动         │
│  [结束] → 保存最后段 + 清理       │
└───────────────────────────────────┘
```

---

## 边界场景处理

| 场景 | 处理方式 |
|------|----------|
| 20~30s 内始终无停顿 | 30s 硬截断，与当前行为一致 |
| 20s 刚过立刻静音 | 立即截断，段时长约 20~21s |
| 整段都是持续说话 | 30s 硬截断 |
| 暂停后恢复 | 新段从 0 开始计时，VAD 重新初始化 |
| VAD 在截断切换期间再次触发 | `_segmentSwitching` 锁防止重入 |
| 录音结束时不足 20s | `stopMeeting()` 直接保存当前段，不走 VAD |

---

## 实施步骤

1. **修改 `MeetingRecordingService`**：
   - 添加智能分段成员变量和参数
   - 替换 `_segmentTimer` 为 VAD + 硬截断 Timer 组合
   - 修正 `_finalizeCurrentSegment` 的时长计算
   - 更新 `pause()` / `resume()` / `stopMeeting()` 清理逻辑

2. **更新 `MeetingProvider`**：
   - 透传新参数（使用默认值，无需改 UI）

3. **补充单元测试**：
   - 测试 20s 前不截断
   - 测试 20~30s 内静音触发截断
   - 测试 30s 强制截断
   - 测试暂停/恢复后重新计时

---

## 不需要改动的部分

- **`VadService`**：现有实现已满足需求，只需在实例化时传入合适参数
- **`AudioRecorderService`**：已提供 `amplitudeStream`，无需改动
- **STT / 纠错 / 增强流水线**：分段方式透明，不受影响
- **数据库 Schema**：`MeetingSegment` 已有 `duration` 字段，无需迁移
- **UI 层**：无需改动，分段时长变化对用户透明
