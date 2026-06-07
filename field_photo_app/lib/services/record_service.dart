import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/field_record.dart';
import '../models/mission_session.dart';

class RecordService {
  static final RecordService _instance = RecordService._internal();
  factory RecordService() => _instance;
  RecordService._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'field_inspection.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            mode TEXT NOT NULL,
            purpose TEXT NOT NULL,
            fields TEXT NOT NULL,
            statusButtons TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sessionId INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            address TEXT NOT NULL,
            jimok TEXT NOT NULL,
            lat REAL,
            lng REAL,
            imagePath TEXT NOT NULL,
            memoData TEXT NOT NULL,
            aiAnalysis TEXT,
            FOREIGN KEY (sessionId) REFERENCES sessions(id)
          )
        ''');
      },
    );
  }

  // ── 세션 ──────────────────────────────────────────────

  Future<MissionSession> insertSession(MissionSession session) async {
    final database = await db;
    final id = await database.insert('sessions', session.toMap());
    return session.copyWith(id: id);
  }

  /// 오늘 날짜 세션 조회. 없으면 null 반환.
  Future<MissionSession?> getTodaySession() async {
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final database = await db;
    final rows = await database.query(
      'sessions',
      where: 'date = ?',
      whereArgs: [today],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MissionSession.fromMap(rows.first);
  }

  /// 최근 N개 세션 반환 (템플릿 선택용).
  Future<List<MissionSession>> getRecentSessions(int limit) async {
    final database = await db;
    final rows = await database.query(
      'sessions',
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(MissionSession.fromMap).toList();
  }

  Future<void> deleteSession(int id) async {
    final database = await db;
    await database.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ── 기록 ──────────────────────────────────────────────

  Future<FieldRecord> insertRecord(FieldRecord record) async {
    final database = await db;
    final id = await database.insert('records', record.toMap());
    return record.copyWith(id: id);
  }

  Future<List<FieldRecord>> getRecordsBySession(int sessionId) async {
    final database = await db;
    final rows = await database.query(
      'records',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'id ASC',
    );
    return rows.map(FieldRecord.fromMap).toList();
  }

  /// date 형식: 'yyyy-MM-dd'
  Future<List<FieldRecord>> getRecordsByDate(String date) async {
    final database = await db;
    // timestamp는 ISO8601 문자열이므로 날짜 접두어로 필터링
    final rows = await database.query(
      'records',
      where: "timestamp LIKE ?",
      whereArgs: ['$date%'],
      orderBy: 'id ASC',
    );
    return rows.map(FieldRecord.fromMap).toList();
  }

  /// aiAnalysis 등 필드 업데이트 시 사용. id가 반드시 있어야 함.
  Future<void> updateRecord(FieldRecord record) async {
    assert(record.id != null, 'updateRecord: id가 null입니다.');
    final database = await db;
    await database.update(
      'records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> deleteRecord(int id) async {
    final database = await db;
    await database.delete('records', where: 'id = ?', whereArgs: [id]);
  }
}
