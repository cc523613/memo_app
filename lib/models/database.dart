import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'memo.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('memos.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDb);
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE memos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        tag TEXT,
        reminderTime TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<List<Memo>> getMemos() async {
    final db = await database;
    final maps = await db.query('memos', where: 'isDeleted = 0');
    return maps.map((e) => Memo.fromMap(e)).toList();
  }

  Future<List<Memo>> getDeletedMemos() async {
    final db = await database;
    final maps = await db.query('memos', where: 'isDeleted = 1');
    return maps.map((e) => Memo.fromMap(e)).toList();
  }

  Future<List<Memo>> searchMemos(String query) async {
    final db = await database;
    final maps = await db.query(
      'memos',
      where: 'isDeleted = 0 AND (title LIKE ? OR content LIKE ?)',
      whereArgs: ['%$query%', '%$query%'],
    );
    return maps.map((e) => Memo.fromMap(e)).toList();
  }

  Future<List<String>> getTags() async {
    final db = await database;
    final maps = await db.query('memos', distinct: true, columns: ['tag']);
    final tags = maps
        .map((e) => e['tag'] as String?)
        .where((tag) => tag != null && tag.trim().isNotEmpty)
        .map((tag) => tag!.trim().toLowerCase())
        .toSet()
        .toList()
      ..sort();
    return ['无标签', ...tags];
  }

  Future<int> insertMemo(Memo memo) async {
    final db = await database;
    debugPrint('插入备忘录: ${memo.toMap()}');
    try {
      return await db.insert('memos', memo.toMap());
    } catch (e) {
      debugPrint('插入失败: $e');
      rethrow;
    }
  }

  Future<void> updateMemo(Memo memo) async {
    final db = await database;
    debugPrint('更新备忘录: ${memo.toMap()}');
    try {
      await db.update(
        'memos',
        memo.toMap(),
        where: 'id = ?',
        whereArgs: [memo.id],
      );
    } catch (e) {
      debugPrint('更新失败: $e');
      rethrow;
    }
  }

  Future<void> deleteMemo(int id, {bool permanent = false}) async {
    final db = await database;
    if (permanent) {
      await db.delete('memos', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        'memos',
        {'isDeleted': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> restoreMemo(int id) async {
    final db = await database;
    await db.update(
      'memos',
      {'isDeleted': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}