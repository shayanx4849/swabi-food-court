class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'read': read,
    };
  }

  factory NotificationItem.fromMap(String id, Map<dynamic, dynamic> map) {
    return NotificationItem(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      read: map['read'] ?? false,
    );
  }
}
