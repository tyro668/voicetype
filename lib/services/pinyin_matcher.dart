import 'package:lpinyin/lpinyin.dart';
import '../models/dictionary_entry.dart';

enum PinyinMatchType { literal, pinyinExact, pinyinFuzzy }

class PinyinMatchHit {
  final DictionaryEntry entry;
  final String observedText;
  final PinyinMatchType matchType;

  const PinyinMatchHit({
    required this.entry,
    required this.observedText,
    required this.matchType,
  });
}

/// 拼音模糊匹配引擎。
///
/// 维护一个 拼音 → DictionaryEntry 列表的哈希索引。
/// 当 ASR 返回文本后，对文本计算拼音并与索引做模糊匹配，
/// 返回命中的词典条目（即"最小化关联字典"）。
class PinyinMatcher {
  final bool enableSingleCharFuzzy;

  PinyinMatcher({this.enableSingleCharFuzzy = false});

  /// 拼音倒排索引：无声调拼音 → 词典条目列表
  final Map<String, List<DictionaryEntry>> _pinyinIndex = {};

  /// 模糊召回桶：声母签名+音节数 -> 拼音键集合
  final Map<String, List<String>> _fuzzyBucketIndex = {};

  final Set<String> _allPinyinKeys = {};

  /// 原始词字面索引：用于快速精确匹配
  final Map<String, List<DictionaryEntry>> _literalIndex = {};

  /// 构建 / 重建拼音索引。
  ///
  /// 仅索引已启用的条目。应在词典变更后调用。
  void buildIndex(List<DictionaryEntry> entries) {
    _pinyinIndex.clear();
    _literalIndex.clear();
    _fuzzyBucketIndex.clear();
    _allPinyinKeys.clear();

    for (final entry in entries) {
      if (!entry.enabled) continue;

      // 1. 精确字面索引（original 原文）
      final lowerOriginal = entry.original.trim().toLowerCase();
      if (lowerOriginal.isNotEmpty) {
        _literalIndex.putIfAbsent(lowerOriginal, () => []).add(entry);
      }

      // 2. 拼音索引
      final pinyin = entry.pinyinNormalized;
      if (pinyin.isNotEmpty) {
        _pinyinIndex.putIfAbsent(pinyin, () => []).add(entry);
        _addPinyinKey(pinyin);
      }

      // 3. 对 corrected 也建索引（用于检测 ASR 是否已正确输出）
      if (entry.corrected != null && entry.corrected!.isNotEmpty) {
        final correctedPinyin = _normalizePinyin(entry.corrected!);
        if (correctedPinyin.isNotEmpty && correctedPinyin != pinyin) {
          _pinyinIndex.putIfAbsent(correctedPinyin, () => []).add(entry);
          _addPinyinKey(correctedPinyin);
        }
        final lowerCorrected = entry.corrected!.toLowerCase();
        if (lowerCorrected.isNotEmpty && lowerCorrected != lowerOriginal) {
          _literalIndex.putIfAbsent(lowerCorrected, () => []).add(entry);
        }
      }
    }
  }

  /// 在输入文本中查找所有与词典匹配的条目。
  ///
  /// 采用滑动窗口策略：从长到短尝试提取子串，
  /// 先做字面精确匹配，再做拼音匹配。
  /// 返回去重后的命中条目列表。
  List<DictionaryEntry> findMatches(String text) {
    final hits = findMatchHits(text);
    final matched = <String, DictionaryEntry>{};
    for (final hit in hits) {
      matched.putIfAbsent(hit.entry.id, () => hit.entry);
    }
    return matched.values.toList();
  }

  /// 在输入文本中查找命中片段与词典条目的映射。
  ///
  /// 相比 [findMatches]，该方法保留了输入中实际命中的子串 observedText，
  /// 可用于构建「命中变体 -> 标准词」的自动纠错规则。
  List<PinyinMatchHit> findMatchHits(String text) {
    if (_pinyinIndex.isEmpty && _literalIndex.isEmpty) return [];
    if (text.trim().isEmpty) return [];

    final matched = <String, PinyinMatchHit>{};
    final chars = text.replaceAll(RegExp(r'\s+'), '');

    // 获取索引中最长词的字符数，作为窗口上限
    final maxLen = _maxKeyLength();
    final minLen = 1;

    // 滑动窗口：从长到短扫描
    for (var len = maxLen.clamp(1, chars.length); len >= minLen; len--) {
      for (var i = 0; i <= chars.length - len; i++) {
        final sub = chars.substring(i, i + len);

        // 1. 字面精确匹配
        final lowerSub = sub.toLowerCase();
        final literalHits = _literalIndex[lowerSub];
        if (literalHits != null) {
          _putHits(matched, literalHits, sub, PinyinMatchType.literal);
          continue; // 已匹配，无需拼音检查
        }

        // 2. 拼音匹配（仅对中文子串）
        if (_containsChinese(sub)) {
          final subPinyin = _normalizePinyin(sub);
          if (subPinyin.isEmpty) continue;

          // 精确拼音匹配
          final pinyinHits = _pinyinIndex[subPinyin];
          if (pinyinHits != null) {
            _putHits(matched, pinyinHits, sub, PinyinMatchType.pinyinExact);
            continue;
          }

          // 模糊拼音匹配：仅对长度>=2（默认），并使用桶索引缩小候选范围
          if (len <= 1 && !enableSingleCharFuzzy) {
            continue;
          }
          for (final key in _candidateFuzzyKeys(subPinyin)) {
            final entries = _pinyinIndex[key];
            if (entries == null) continue;
            if (_isFuzzyMatch(subPinyin, key)) {
              _putHits(matched, entries, sub, PinyinMatchType.pinyinFuzzy);
            }
          }
        }
      }
    }

    return matched.values.toList();
  }

  void _putHits(
    Map<String, PinyinMatchHit> matched,
    List<DictionaryEntry> entries,
    String observedText,
    PinyinMatchType matchType,
  ) {
    for (final entry in entries) {
      final key = '${entry.id}|$observedText';
      final existing = matched[key];
      if (existing == null ||
          _matchPriority(matchType) > _matchPriority(existing.matchType)) {
        matched[key] = PinyinMatchHit(
          entry: entry,
          observedText: observedText,
          matchType: matchType,
        );
      }
    }
  }

  int _matchPriority(PinyinMatchType type) {
    switch (type) {
      case PinyinMatchType.literal:
        return 3;
      case PinyinMatchType.pinyinExact:
        return 2;
      case PinyinMatchType.pinyinFuzzy:
        return 1;
    }
  }

  /// 获取索引中最长词的字符数量
  int _maxKeyLength() {
    var maxLen = 0;
    for (final key in _literalIndex.keys) {
      if (key.length > maxLen) maxLen = key.length;
    }
    // 拼音索引的键是拼音不是原文，需要从条目中获取原文长度
    for (final entries in _pinyinIndex.values) {
      for (final e in entries) {
        final origLen = e.original.replaceAll(RegExp(r'\s+'), '').length;
        if (origLen > maxLen) maxLen = origLen;
        if (e.corrected != null) {
          final corrLen = e.corrected!.replaceAll(RegExp(r'\s+'), '').length;
          if (corrLen > maxLen) maxLen = corrLen;
        }
        if (e.pinyinPattern != null && e.pinyinPattern!.trim().isNotEmpty) {
          final syllableCount = e.pinyinPattern!
              .trim()
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty)
              .length;
          if (syllableCount > maxLen) maxLen = syllableCount;
        }
      }
    }
    return maxLen;
  }

  /// 模糊匹配：两个拼音串的声母序列相同，且整体编辑距离 ≤ 阈值。
  bool _isFuzzyMatch(String pinyin1, String pinyin2) {
    final parts1 = pinyin1.split(' ');
    final parts2 = pinyin2.split(' ');
    if (parts1.length != parts2.length) return false;

    // 声母必须完全相同
    for (var i = 0; i < parts1.length; i++) {
      final sm1 = _getShengmu(parts1[i]);
      final sm2 = _getShengmu(parts2[i]);
      if (sm1 != sm2) return false;
    }

    // 整体编辑距离 ≤ 1（允许韵母有一个字符差异）
    return _editDistance(pinyin1, pinyin2) <= 1;
  }

  /// 提取拼音音节的声母部分。
  String _getShengmu(String syllable) {
    const shengmuList = [
      'zh', 'ch', 'sh', // 双字母声母优先
      'b', 'p', 'm', 'f',
      'd', 't', 'n', 'l',
      'g', 'k', 'h',
      'j', 'q', 'x',
      'r', 'z', 'c', 's',
      'y', 'w',
    ];
    final lower = syllable.toLowerCase();
    for (final sm in shengmuList) {
      if (lower.startsWith(sm)) return sm;
    }
    return ''; // 零声母
  }

  /// 计算两个字符串的编辑距离 (Levenshtein)
  int _editDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    final len1 = s1.length;
    final len2 = s2.length;
    if (len1 == 0) return len2;
    if (len2 == 0) return len1;

    // 优化：如果长度差距过大，直接返回大值
    if ((len1 - len2).abs() > 2) return (len1 - len2).abs();

    var prev = List.generate(len2 + 1, (i) => i);
    var curr = List.filled(len2 + 1, 0);

    for (var i = 1; i <= len1; i++) {
      curr[0] = i;
      for (var j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[len2];
  }

  /// 标准化拼音：无声调、小写、空格分隔。
  static String _normalizePinyin(String text) {
    if (text.trim().isEmpty) return '';
    try {
      return PinyinHelper.getPinyinE(
            text,
            separator: ' ',
            defPinyin: '#',
            format: PinyinFormat.WITHOUT_TONE,
          )
          .toLowerCase()
          .replaceAll('#', '')
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
    } catch (_) {
      return '';
    }
  }

  /// 供外部调用的拼音计算方法。
  static String computePinyin(String text) => _normalizePinyin(text);

  /// 检测字符串是否包含中文字符
  static bool _containsChinese(String text) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  void _addPinyinKey(String pinyinKey) {
    if (!_allPinyinKeys.add(pinyinKey)) return;
    final bucketKey = _fuzzyBucketKey(pinyinKey);
    _fuzzyBucketIndex.putIfAbsent(bucketKey, () => []).add(pinyinKey);
  }

  Iterable<String> _candidateFuzzyKeys(String pinyin) {
    final bucketKey = _fuzzyBucketKey(pinyin);
    final bucket = _fuzzyBucketIndex[bucketKey];
    if (bucket == null || bucket.isEmpty) {
      return _allPinyinKeys;
    }
    return bucket;
  }

  String _fuzzyBucketKey(String pinyin) {
    final parts = pinyin.split(' ').where((e) => e.isNotEmpty).toList();
    final shengmuSig = parts.map(_getShengmu).join('-');
    return '${parts.length}|$shengmuSig';
  }
}
