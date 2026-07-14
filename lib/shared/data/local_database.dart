import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase(this._factory, this._path);

  static const schemaVersion = 1;
  final DatabaseFactory _factory;
  final String _path;
  Database? _database;

  static Future<LocalDatabase> createDefault() async {
    final support = await getApplicationSupportDirectory();
    return LocalDatabase(
      databaseFactory,
      p.join(support.path, 'flow_reading.sqlite'),
    );
  }

  Future<Database> get database async =>
      _database ??= await _factory.openDatabase(
        _path,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
            await db.execute('PRAGMA journal_mode = WAL');
          },
          onCreate: (db, version) => _createSchema(db),
          onUpgrade: _migrate,
        ),
      );

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  static Future<void> _migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Version 1 is the prototype baseline. Every future version must add an
    // ordered migration here; docs/persistence.md records the reset policy.
    if (oldVersion < 1) await _createSchema(db);
  }

  static Future<void> _createSchema(Database db) async {
    final statements = <String>[
      '''CREATE TABLE books (
        id TEXT PRIMARY KEY,
        source_fingerprint TEXT NOT NULL UNIQUE,
        source_path TEXT NOT NULL,
        title TEXT NOT NULL,
        authors TEXT NOT NULL,
        language TEXT NOT NULL,
        cover_image_id TEXT,
        imported_at TEXT NOT NULL,
        model_version INTEGER NOT NULL,
        model_json TEXT NOT NULL
      )''',
      '''CREATE TABLE chapters (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        source_href TEXT NOT NULL,
        spine_order INTEGER NOT NULL,
        chapter_json TEXT NOT NULL
      )''',
      '''CREATE TABLE canonical_content (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        chapter_id TEXT NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
        parent_id TEXT,
        node_type TEXT NOT NULL,
        ordinal INTEGER NOT NULL,
        plain_text TEXT,
        content_json TEXT NOT NULL
      )''',
      '''CREATE TABLE reading_states (
        book_id TEXT PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE,
        content_id TEXT NOT NULL,
        character_offset INTEGER NOT NULL,
        word_offset INTEGER NOT NULL,
        locator_json TEXT NOT NULL,
        progress REAL NOT NULL CHECK(progress >= 0 AND progress <= 1),
        last_opened_at TEXT,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE annotations (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        start_content_id TEXT NOT NULL,
        end_content_id TEXT NOT NULL,
        annotation_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE ai_cache (
        cache_key TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        result_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )''',
      '''CREATE TABLE translations (
        cache_key TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        content_id TEXT NOT NULL,
        source_revision INTEGER NOT NULL,
        target_language TEXT NOT NULL,
        glossary_revision INTEGER NOT NULL,
        translation_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )''',
      '''CREATE TABLE glossary_entries (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        source_term TEXT NOT NULL,
        target_language TEXT NOT NULL,
        revision INTEGER NOT NULL,
        entry_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE chapter_overviews (
        chapter_id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        overview_json TEXT NOT NULL,
        generated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        title TEXT,
        saved INTEGER NOT NULL DEFAULT 0,
        conversation_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE conversation_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
        ordinal INTEGER NOT NULL,
        role TEXT NOT NULL,
        content_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )''',
      '''CREATE TABLE pending_sync_operations (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        next_attempt_at TEXT
      )''',
      'CREATE INDEX idx_chapters_book_order ON chapters(book_id, spine_order)',
      'CREATE INDEX idx_content_book_chapter_order ON canonical_content(book_id, chapter_id, ordinal)',
      'CREATE INDEX idx_annotations_book ON annotations(book_id, updated_at)',
      'CREATE INDEX idx_ai_cache_book_kind ON ai_cache(book_id, kind)',
      'CREATE INDEX idx_translations_content ON translations(book_id, content_id, target_language)',
      'CREATE INDEX idx_glossary_book_term ON glossary_entries(book_id, source_term)',
      'CREATE INDEX idx_conversations_book ON conversations(book_id, updated_at)',
      'CREATE INDEX idx_sync_due ON pending_sync_operations(next_attempt_at, created_at)',
      '''CREATE VIRTUAL TABLE content_fts USING fts5(
        content_id UNINDEXED, book_id UNINDEXED, chapter_id UNINDEXED, plain_text
      )''',
    ];
    for (final statement in statements) {
      await db.execute(statement);
    }
  }
}
