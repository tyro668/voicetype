class CorrectionTermPair {
  final String observed;
  final String original;
  final String corrected;

  const CorrectionTermPair({
    required this.observed,
    required this.original,
    required this.corrected,
  });

  Map<String, dynamic> toJson() => {
    'observed': observed,
    'original': original,
    'corrected': corrected,
  };

  factory CorrectionTermPair.fromJson(Map<String, dynamic> json) {
    return CorrectionTermPair(
      observed: (json['observed'] as String? ?? '').trim(),
      original: (json['original'] as String? ?? '').trim(),
      corrected: (json['corrected'] as String? ?? '').trim(),
    );
  }
}

class CorrectionChangeLog {
  final DateTime createdAt;
  final String source;
  final String inputText;
  final String outputText;
  final List<CorrectionTermPair> terms;

  const CorrectionChangeLog({
    required this.createdAt,
    required this.source,
    required this.inputText,
    required this.outputText,
    required this.terms,
  });

  Map<String, dynamic> toJson() => {
    'createdAt': createdAt.toIso8601String(),
    'source': source,
    'inputText': inputText,
    'outputText': outputText,
    'terms': terms.map((e) => e.toJson()).toList(growable: false),
  };

  factory CorrectionChangeLog.fromJson(Map<String, dynamic> json) {
    final termsRaw = json['terms'];
    final terms = <CorrectionTermPair>[];
    if (termsRaw is List) {
      for (final item in termsRaw) {
        if (item is Map<String, dynamic>) {
          terms.add(CorrectionTermPair.fromJson(item));
        } else if (item is Map) {
          terms.add(CorrectionTermPair.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return CorrectionChangeLog(
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      source: (json['source'] as String? ?? 'realtime').trim(),
      inputText: (json['inputText'] as String? ?? '').trim(),
      outputText: (json['outputText'] as String? ?? '').trim(),
      terms: terms,
    );
  }
}
