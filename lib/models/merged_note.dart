import '../services/log_service.dart';

/// 窗口大小钳位函数：将 [value] 限制在 [2, 10] 范围内。
/// 小于 2 修正为 2 并记录警告，大于 10 修正为 10 并记录警告。
int clampWindowSize(int value) {
  if (value < 2) {
    LogService.warn(
      'MERGER',
      'windowSize $value is below minimum, clamped to 2',
    );
    return 2;
  }
  if (value > 10) {
    LogService.warn(
      'MERGER',
      'windowSize $value exceeds maximum, clamped to 10',
    );
    return 10;
  }
  return value;
}

/// 合并纪要模型，由 SlidingWindowMerger 对窗口内多段文本合并增强后产生
class MergedNote {
  /// 窗口起始分段索引
  final int startSegmentIndex;

  /// 窗口结束分段索引
  final int endSegmentIndex;

  /// 合并增强后的文本内容
  final String content;

  /// 创建时间
  final DateTime createdAt;

  const MergedNote({
    required this.startSegmentIndex,
    required this.endSegmentIndex,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'startSegmentIndex': startSegmentIndex,
    'endSegmentIndex': endSegmentIndex,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MergedNote.fromJson(Map<String, dynamic> json) => MergedNote(
    startSegmentIndex: json['startSegmentIndex'] as int,
    endSegmentIndex: json['endSegmentIndex'] as int,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// 合并流式输出事件，用于 SSE 流式输出过程中逐 token 推送
class MergeStreamEvent {
  /// 本次流式输出的文本片段
  final String chunk;

  /// 窗口起始分段索引
  final int startSegmentIndex;

  /// 窗口结束分段索引
  final int endSegmentIndex;

  /// 是否为流式输出的最后一个片段
  final bool isComplete;

  const MergeStreamEvent({
    required this.chunk,
    required this.startSegmentIndex,
    required this.endSegmentIndex,
    required this.isComplete,
  });
}
