import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE memos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      tag TEXT,
      reminderTime TEXT,
      isDeleted INTEGER NOT NULL
    )
    ''');
  }

  Future<List<Memo>> getMemos({bool includeDeleted = false}) async {
    final db = await database;
    final maps = await db.query(
      'memos',
      where: includeDeleted ? null : 'isDeleted = ?',
      whereArgs: includeDeleted ? null : [0],
      orderBy: 'timestamp DESC',
    );
    return maps.map((e) => Memo.fromMap(e)).toList();
  }

  Future<List<Memo>> getDeletedMemos() async {
    final db = await database;
    final maps = await db.query(
      'memos',
      where: 'isDeleted = ?',
      whereArgs: [1],
      orderBy: 'timestamp DESC',
    );
    return maps.map((e) => Memo.fromMap(e)).toList();
  }


  Future<List<String>> getTags() async {
    final db = await database;
    final maps = await db.query('memos', distinct: true, columns: ['tag']);
    final tags = maps
        .map((e) => e['tag'] as String?)
        .where((tag) => tag != null && tag.isNotEmpty)
        .cast<String>() // Cast to non-nullable String
        .toSet()
        .toList();
    tags.add('无标签');
    return tags;
  }

  Future<void> insertMemo(Memo memo) async {
    final db = await database;
    await db.insert('memos', memo.toMap());
  }

  Future<void> updateMemo(Memo memo) async {
    final db = await database;
    await db.update(
      'memos',
      memo.toMap(),
      where: 'id = ?',
      whereArgs: [memo.id],
    );
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

  Future<List<Memo>> searchMemos(String query) async {
    final db = await database;
    final maps = await db.query(
      'memos',
      where: 'isDeleted = 0 AND (title LIKE ? OR content LIKE ?)',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((e) => Memo.fromMap(e)).toList();
  }
}