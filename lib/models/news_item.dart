/// An announcement shown to clients on the home screen.
class NewsItem {
  const NewsItem({
    required this.id,
    required this.text,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String text;
  final bool isActive;
  final DateTime createdAt;

  factory NewsItem.fromMap(Map<String, dynamic> map) {
    return NewsItem(
      id: map['id'] as String,
      text: map['text'] as String,
      isActive: (map['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
