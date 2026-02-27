/// 纠错上下文管理器。
///
/// 维护最近 N 段已纠错文本，用于辅助 LLM 判断同音字歧义。
/// 生命周期跟随录音会话，每次 startRecording 时重置。
class CorrectionContext {
  /// 默认保留最近 5 段
  static const int defaultMaxSegments = 5;

  final int maxSegments;
  final List<String> _recentSegments = [];

  CorrectionContext({this.maxSegments = defaultMaxSegments});

  /// 添加一段已纠错文本到上下文窗口。
  void addSegment(String correctedText) {
    final trimmed = correctedText.trim();
    if (trimmed.isEmpty) return;

    _recentSegments.add(trimmed);
    // 维护窗口大小
    while (_recentSegments.length > maxSegments) {
      _recentSegments.removeAt(0);
    }
  }

  /// 获取上下文字符串，用于注入到纠错 prompt 的 #C 字段。
  ///
  /// 返回最近几段文本，以换行分隔。
  /// 若无上下文则返回空字符串。
  String getContextString() {
    if (_recentSegments.isEmpty) return '';
    return _recentSegments.join('\n');
  }

  /// 上下文是否非空
  bool get hasContext => _recentSegments.isNotEmpty;

  /// 当前上下文段数
  int get segmentCount => _recentSegments.length;

  /// 重置上下文（新录音会话开始时调用）。
  void reset() {
    _recentSegments.clear();
  }
}
