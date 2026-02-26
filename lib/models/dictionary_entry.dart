import 'package:uuid/uuid.dart';

/// A dictionary entry that stores commonly used words/phrases
/// to help the AI model produce better output.
class DictionaryEntry {
  final String id;
  final String word;
  final String? description;
  final DateTime createdAt;

  const DictionaryEntry({
    required this.id,
    required this.word,
    this.description,
    required this.createdAt,
  });

  factory DictionaryEntry.create({
    required String word,
    String? description,
  }) {
    return DictionaryEntry(
      id: const Uuid().v4(),
      word: word,
      description: description,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      id: json['id'] as String,
      word: json['word'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  DictionaryEntry copyWith({
    String? word,
    String? description,
  }) {
    return DictionaryEntry(
      id: id,
      word: word ?? this.word,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}
