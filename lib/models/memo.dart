class Memo {
  final int? id;
  final String title;
  final String content;
  final String timestamp;
  final String? tag;
  final DateTime? reminderTime;
  final bool isDeleted;

  Memo({
    this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    this.tag,
    this.reminderTime,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'timestamp': timestamp,
      'tag': tag,
      'reminderTime': reminderTime?.toIso8601String(),
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory Memo.fromMap(Map<String, dynamic> map) {
    return Memo(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      timestamp: map['timestamp'] as String,
      tag: map['tag'] as String?,
      reminderTime: map['reminderTime'] != null
          ? DateTime.parse(map['reminderTime'])
          : null,
      isDeleted: (map['isDeleted'] as int) == 1,
    );
  }
}