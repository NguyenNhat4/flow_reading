import 'package:sqflite/sqflite.dart';

final class AppDatabase {
  factory AppDatabase({DatabaseFactory? factory, String? path}) {
    return AppDatabase._(factory ?? databaseFactory, path);
  }

  AppDatabase._(this._factory, this._path);

  static const schemaVersion = 1;

  final DatabaseFactory _factory;
  final String? _path;
  Database? _database;

  Future<Database> open() async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;
    final path = _path ?? '${await getDatabasesPath()}/flow_reading.db';
    final database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createVersion1,
        onUpgrade: _upgrade,
      ),
    );
    _database = database;
    return database;
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null && database.isOpen) await database.close();
  }

  static Future<void> _upgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) await _createVersion1(database, 1);
  }

  static Future<void> _createVersion1(Database database, int version) async {
    final batch = database.batch()
      ..execute('''
CREATE TABLE books (
  id TEXT PRIMARY KEY,
  content_hash TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  authors_json TEXT NOT NULL,
  metadata_json TEXT NOT NULL,
  original_file TEXT NOT NULL,
  toc_json TEXT NOT NULL,
  assets_json TEXT NOT NULL,
  detected_language TEXT,
  imported_at TEXT NOT NULL
)''')
      ..execute('''
CREATE TABLE chapters (
  id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  spine_order INTEGER NOT NULL,
  source_href TEXT,
  UNIQUE(book_id, spine_order)
)''')
      ..execute('''
CREATE TABLE chapter_content (
  chapter_id TEXT PRIMARY KEY REFERENCES chapters(id) ON DELETE CASCADE,
  schema_version INTEGER NOT NULL,
  content_json TEXT NOT NULL
)''')
      ..execute('''
CREATE TABLE reading_states (
  book_id TEXT PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE,
  anchor_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''')
      ..execute('''
CREATE TABLE annotations (
  id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  range_json TEXT NOT NULL,
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''')
      ..execute('''
CREATE TABLE bookmarks (
  id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  anchor_json TEXT NOT NULL,
  created_at TEXT NOT NULL
)''')
      ..execute('''
CREATE TABLE notes (
  id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  range_json TEXT NOT NULL,
  note TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''')
      ..execute('''
CREATE TABLE ai_artifacts (
  id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  source_range_json TEXT,
  response_json TEXT NOT NULL,
  provider TEXT,
  model TEXT,
  created_at TEXT NOT NULL
)''')
      ..execute('''
CREATE TABLE chat_sessions (
  id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  title TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''')
      ..execute('''
CREATE TABLE chat_messages (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  text TEXT NOT NULL,
  referenced_ranges_json TEXT NOT NULL,
  created_at TEXT NOT NULL
)''')
      ..execute('''
CREATE TABLE glossary_terms (
  id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  source_term TEXT NOT NULL,
  target_term TEXT NOT NULL,
  notes TEXT,
  UNIQUE(book_id, source_term)
)''')
      ..execute('''
CREATE TABLE reader_preferences (
  id INTEGER PRIMARY KEY CHECK(id = 1),
  preferences_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''')
      ..execute('''
CREATE TABLE sync_outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0
)''')
      ..execute(
        'CREATE INDEX chapters_book_order ON chapters(book_id, spine_order)',
      )
      ..execute('CREATE INDEX annotations_book ON annotations(book_id)')
      ..execute('CREATE INDEX bookmarks_book ON bookmarks(book_id)')
      ..execute('CREATE INDEX notes_book ON notes(book_id)')
      ..execute('CREATE INDEX ai_artifacts_book ON ai_artifacts(book_id)')
      ..execute('CREATE INDEX chat_sessions_book ON chat_sessions(book_id)');
    await batch.commit(noResult: true);
  }
}
