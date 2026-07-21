class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.plainContent,
    required this.mood,
    required this.createdAt,
    required this.updatedAt,
    this.weather,
  });

  final String id;
  final String title;
  final String content;
  final String plainContent;
  final String mood;
  final String? weather;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiaryEntry copyWith({
    String? id,
    String? title,
    String? content,
    String? plainContent,
    String? mood,
    String? weather,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      plainContent: plainContent ?? this.plainContent,
      mood: mood ?? this.mood,
      weather: weather ?? this.weather,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
