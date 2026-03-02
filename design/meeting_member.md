# 会议记录说话人区分方案（本地 3D-Speaker 版）

## 1. 目标

- 显著提升“多人会议被归成同一人”的问题，优先提升 2~8 人会议可分性。
- 保持纯本地链路（macOS / Windows），不依赖云端。
- 将声纹主模型统一为 3D-Speaker，减少模型分叉和参数漂移。

## 2. 当前问题与根因

当前区分效果差，通常由以下原因叠加：

- 旧特征/旧 embedding 对真实会议噪声、近场/远场切换鲁棒性不足。
- 固定阈值在不同设备与会议场景下不稳定，容易过分裂或过并类。
- 只做在线单次决策，缺少会后全局修正。
- 对重叠语音、短片段、噪声片段缺少专门抑制策略。

## 3. 推荐方案（3D-Speaker）

采用“两阶段 diarization”：

1. **实时阶段（Online）**：保障低延迟显示 speaker 标签。
2. **会后阶段（Offline refine）**：做全局重聚类修正误分。

核心链路：

`VAD + 预处理 + 3D-Speaker Embedding + Online 聚类 + Offline 重聚类`

> 说明：仍然不引入 Pyannote，保持纯本地推理。实现优先采用 ONNX Runtime（CPU），必要时保留本地原生推理后端扩展位。

## 4. 模型与算法选型

### 4.1 Speaker Embedding 模型（统一为 3D-Speaker）

统一采用 3D-Speaker 预训练 embedding 作为主模型：

- **主模型：3D-Speaker（embedding 维度按导出模型确定，常见 192/256）**
  - 对说话人区分任务针对性更强，适合会议 diarization。
  - 通过固定前处理与向量归一化，减少跨设备抖动。
- **部署形态：本地模型文件 + 本地推理引擎**
  - 优先 ONNX Runtime CPU 推理，跨平台一致性更好。
  - 预留后端接口，便于后续切换更快推理实现。

实施建议：以 3D-Speaker 为唯一主链路，不再并行维护 ECAPA/CAMPPlus 作为默认方案。

### 4.2 聚类策略（关键提升点）

#### 实时阶段（Online）

- 使用“类中心 + 置信度门控”而不是单纯固定阈值。
- 每个 speaker 维护：`centroid`, `count`, `intraSimEMA`。
- 决策规则：
  - 若 `top1Sim >= dynamicThreshold(speaker)` 则归入。
  - 若 `top1Sim - top2Sim < margin` 则标记低置信度，延迟确认。
  - 否则创建新 speaker（受 `maxSpeakers` 与最小时长约束）。

3D-Speaker 专项建议：

- 在线阶段增加“冷启动保护”：前 N 段（建议 6 段）提高新建门槛，减少早期碎片 speaker。
- 对低信噪比片段加入 `reject` 机制，不参与原型更新，仅用于文本显示。

#### 会后阶段（Offline refine）

- 对整场会议 embedding 做一次受约束 AHC（层次聚类）。
- 约束条件：时间连续性、最小时长、最小样本数。
- 重新映射 speaker 编号，修正早期误分与碎片化。

3D-Speaker 专项建议：

- 会后加入“短簇回收”：将极短簇（例如总时长 < 4s）并入最相近主簇。
- 会后输出稳定编号，保证 UI 中 Speaker1..N 尽量不频繁跳号。

## 5. 音频预处理（必须做）

- 统一采样率到 16k mono。
- 子分段切分到 1.0s~3.0s（建议窗口 1.5s，步长 0.75s）。
- 丢弃低能量/过短片段（如 < 600ms）。
- 加入简单降噪与响度归一（避免麦克风增益漂移）。
- 保证前处理与 3D-Speaker 训练/导出约定一致（如归一化区间、vad 后截断方式）。

这一步对提升 embedding 稳定性非常关键。

## 6. 与现有工程的落地方式

### 6.1 服务层改造

- `speaker_diarization_service.dart`
  - 抽象接口：`extractEmbedding()`、`assignOnline()`、`refineOffline()`。
  - 新增模型后端：`ThreeDSpeakerEmbeddingBackend`。
  - 优先实现：`ThreeDSpeakerOnnxBackend`（CPU）。
  - 保留当前简化特征后端仅用于开发调试，不作为生产默认。

### 6.2 流水线接入

- `MeetingRecordingService`
  - 录制中：每个子片段在线分配 speaker，实时展示。
  - 会议结束：触发一次离线重聚类并回写 `meeting_segments`。

### 6.3 数据结构

- `MeetingSegment`
  - 保留：`speakerId`, `speakerConfidence`。
  - 建议新增：`speakerVersion`（online/offline）、`embeddingHash`（可选）。
  - 建议新增：`speakerRejectReason`（可选，便于调试低质量片段）。

## 7. 参数建议（3D-Speaker 首版）

- `maxSpeakers`: 8（固定参会人数时建议设为已知人数）
- `minSegmentMs`: 700
- `onlineBaseThreshold`: 0.80
- `dynamicThresholdRange`: [0.76, 0.88]
- `top1Top2Margin`: 0.05
- `offlineMinClusterDurSec`: 6
- `offlineMergeThreshold`: 0.82
- `coldStartProtectSegments`: 6
- `shortClusterRecycleSec`: 4

> 不再依赖单一固定阈值；按 speaker 内部稳定性自适应调整。

## 8. 质量评估与验收

### 8.1 指标

- 线上可用指标：Speaker 切换点正确率、长段落归属正确率。
- 离线评估指标：DER（Diarization Error Rate）。

### 8.2 验收门槛（建议）

- 2~4 人中文会议：主发言段正确区分率 >= 88%。
- 5~8 人复杂会议：主发言段正确区分率 >= 78%。
- 实时时延增量：单段平均新增 < 250ms（CPU，设备相关）。

## 9. 分阶段实施

### Phase A（1~2 周）

- 接入 3D-Speaker ONNX 本地推理链路。
- 完成 Online 动态阈值聚类与冷启动保护。
- 增加调试日志：`top1/top2 sim`, `threshold`, `decision reason`。

### Phase B（1 周）

- 增加会后 AHC 重聚类并回写。
- 会议详情页支持“应用重聚类结果”。

### Phase C（持续优化）

- 在固定评测集上持续调优 3D-Speaker 参数。
- 引入重叠语音检测（低置信度标记，不强行归类）。
- 建立小型内部评测集做参数回归。

## 10. 结论

当前“区分差”的核心不是 UI 或标签逻辑，而是**声纹模型与聚类策略不足**。最佳升级路径是：

- 用 3D-Speaker 统一替换旧特征/旧 embedding；
- 用“在线 + 离线”两阶段聚类替代单次决策；
- 用动态阈值与评测闭环持续调参。

该路径保持本地化、可逐步落地，且对现有代码改动风险可控。

