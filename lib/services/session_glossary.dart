/// 会话级术语锚定表。
///
/// 生命周期跟随一次录音会话。在录音过程中，当 LLM 完成一次
/// 同音字纠错修正（如 反软 → 帆软），Dart 端自动提取该映射并
/// 存入本表。后续纠错请求会将已锚定的映射强制注入 #R 字段，
/// 确保同一术语在整段录音中保持一致。
///
/// **弱锚定机制**：仅出现 1 次的映射标记为"弱锚定"，不参与
/// 强制注入，避免首次误判在会话内扩散。当 hitCount >= 2 时
/// 升级为"强锚定"。
class SessionGlossary {
  final Map<String, TermPin> _entries = {};

  /// 所有锚定条目（含弱锚定）
  Map<String, TermPin> get entries => Map.unmodifiable(_entries);

  /// 仅返回强锚定条目（hitCount >= 2），用于注入 #R
  Map<String, TermPin> get strongEntries => Map.fromEntries(
        _entries.entries.where((e) => e.value.hitCount >= 2),
      );

  /// 当前条目数量
  int get length => _entries.length;

  /// 是否有强锚定条目
  bool get hasStrongEntries => _entries.values.any((e) => e.hitCount >= 2);

  /// 记录一次 LLM 纠错修正映射。
  ///
  /// [original] 错词（ASR 原始输出中的片段）
  /// [corrected] 正词（LLM 修正后的结果）
  /// [segmentIndex] 当前段号
  ///
  /// 如果该映射已存在，递增 hitCount；否则新建弱锚定条目。
  void pin(String original, String corrected, {int segmentIndex = 0}) {
    final key = original.trim().toLowerCase();
    if (key.isEmpty || corrected.trim().isEmpty) return;
    // 不锚定相同内容
    if (key == corrected.trim().toLowerCase()) return;

    if (_entries.containsKey(key)) {
      _entries[key] = _entries[key]!.copyWithHit();
    } else {
      _entries[key] = TermPin(
        original: original.trim(),
        corrected: corrected.trim(),
        hitCount: 1,
        firstSeenSegment: segmentIndex,
      );
    }
  }

  /// 手动覆盖某个锚定（用户通过词典页纠正时调用）。
  void override(String original, String corrected) {
    final key = original.trim().toLowerCase();
    if (key.isEmpty) return;
    if (corrected.trim().isEmpty) {
      _entries.remove(key);
      return;
    }
    _entries[key] = TermPin(
      original: original.trim(),
      corrected: corrected.trim(),
      hitCount: 2, // 手动覆盖直接为强锚定
      firstSeenSegment: _entries[key]?.firstSeenSegment ?? 0,
    );
  }

  /// 生成强锚定条目的 #R 追加字符串。
  ///
  /// 格式与词典一致：`错词->正词`，多组用 `|` 分隔。
  /// 返回空字符串表示无强锚定需要注入。
  String buildReferenceAppend() {
    final strong = strongEntries;
    if (strong.isEmpty) return '';
    return strong.values.map((e) => '${e.original}->${e.corrected}').join('|');
  }

  /// 根据输入文本和纠错结果，自动提取新的同音字映射。
  ///
  /// 简单策略：按字符级别比对输入与输出，识别连续不同片段。
  /// 仅提取长度 >= 2 的中文片段差异（排除标点、空格噪声）。
  void extractAndPin(
    String inputText,
    String correctedText, {
    int segmentIndex = 0,
  }) {
    if (inputText == correctedText) return;

    // 简单分词：按非中文字符分割
    final inputWords = _extractChineseWords(inputText);
    final correctedWords = _extractChineseWords(correctedText);

    // 对比同位置词组
    final minLen =
        inputWords.length < correctedWords.length
            ? inputWords.length
            : correctedWords.length;

    for (var i = 0; i < minLen; i++) {
      if (inputWords[i] != correctedWords[i] &&
          inputWords[i].length >= 2 &&
          correctedWords[i].length >= 2) {
        pin(inputWords[i], correctedWords[i], segmentIndex: segmentIndex);
      }
    }
  }

  /// 从文本中提取连续中文片段
  List<String> _extractChineseWords(String text) {
    final regex = RegExp(r'[\u4e00-\u9fff]+');
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// 重置（新录音会话开始时调用）。
  void reset() {
    _entries.clear();
  }
}

/// 术语锚定条目。
class TermPin {
  /// 错词（ASR 原始形式）
  final String original;

  /// 正词（纠错后形式）
  final String corrected;

  /// 命中计数
  final int hitCount;

  /// 首次出现的段号
  final int firstSeenSegment;

  const TermPin({
    required this.original,
    required this.corrected,
    required this.hitCount,
    required this.firstSeenSegment,
  });

  /// 创建命中计数 +1 的副本
  TermPin copyWithHit() => TermPin(
        original: original,
        corrected: corrected,
        hitCount: hitCount + 1,
        firstSeenSegment: firstSeenSegment,
      );

  @override
  String toString() =>
      'TermPin($original->$corrected, hits=$hitCount, seg=$firstSeenSegment)';
}
