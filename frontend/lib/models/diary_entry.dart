import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final String mood;
  final DateTime date;
  final List<String> tags;

  static const List<String> moods = [
    'отлично',
    'хорошо',
    'нормально',
    'плохо',
    'ужасно',
  ];

  static const Map<String, String> moodEmojis = {
    'отлично': '😄',
    'хорошо': '😊',
    'нормально': '😐',
    'плохо': '😔',
    'ужасно': '😢',
  };

  DiaryEntry({
    String? id,
    required this.title,
    required this.content,
    this.mood = 'нормально',
    DateTime? date,
    List<String>? tags,
  })  : id = id ?? _uuid.v4(),
        date = date ?? DateTime.now(),
        tags = tags ?? [];

  String get moodEmoji => moodEmojis[mood] ?? '😐';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'mood': mood,
        'date': date.toIso8601String(),
        'tags': tags,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        mood: json['mood'] as String? ?? 'нормально',
        date: DateTime.parse(json['date'] as String),
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  DiaryEntry copyWith({
    String? title,
    String? content,
    String? mood,
    DateTime? date,
    List<String>? tags,
  }) =>
      DiaryEntry(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        mood: mood ?? this.mood,
        date: date ?? this.date,
        tags: tags ?? this.tags,
      );
}
