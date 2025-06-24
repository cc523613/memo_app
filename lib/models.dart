import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class Memo {
  final String content;
  final String timestamp;
  final String tag;

  Memo({
    required this.content,
    required this.timestamp,
    required this.tag,
  });

  Map<String, String> toMap() {
    return {
      'content': content,
      'timestamp': timestamp,
      'tag': tag,
    };
  }

  factory Memo.fromString(String data) {
    final parts = data.split('|');
    return Memo(
      content: parts[0],
      timestamp: parts.length > 1 ? parts[1] : DateTime.now().toString(),
      tag: parts.length > 2 ? parts[2] : '无标签',
    );
  }

  String toStorageString() => '$content|$timestamp|$tag';
}

class MemoStorage {
  static Future<List<Memo>> loadMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMemos = prefs.getStringList('memos') ?? [];
    return savedMemos.map((e) => Memo.fromString(e)).toList();
  }

  static Future<List<String>> loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('tags') ?? ['无标签'];
  }

  static Future<void> saveMemos(List<Memo> memos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'memos', memos.map((e) => e.toStorageString()).toList());
  }

  static Future<void> saveTags(List<String> tags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tags', tags);
  }

  static String formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  // 提取第一行作为标题，移除 Markdown 格式
  static String extractTitle(String content) {
    final firstLine = content.split('\n').first.trim();
    return firstLine
        .replaceAll(RegExp(r'\*{1,2}|_{1,2}|#+\s*'), '')
        .replaceAll(RegExp(r'\[|\]|\(.*?\)'), '')
        .trim();
  }
}