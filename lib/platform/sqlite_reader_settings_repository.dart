import 'dart:convert';

import 'package:flow_reading/platform/app_database.dart';
import 'package:flow_reading/settings/reader_settings.dart';
import 'package:flow_reading/shared/app_failure.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteReaderSettingsRepository implements ReaderSettingsRepository {
  SqliteReaderSettingsRepository(this.appDatabase);

  final AppDatabase appDatabase;

  @override
  Future<ReaderSettings> load() => _guard(() async {
    final database = await appDatabase.open();
    final rows = await database.query(
      'reader_preferences',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return ReaderSettings.defaults;
    try {
      final decoded = jsonDecode(rows.single['preferences_json'] as String);
      if (decoded is! Map) return ReaderSettings.defaults;
      return ReaderSettings.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return ReaderSettings.defaults;
    }
  });

  @override
  Future<void> save(ReaderSettings settings) => _guard(() async {
    final database = await appDatabase.open();
    await database.insert('reader_preferences', {
      'id': 1,
      'preferences_json': jsonEncode(settings.toJson()),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  static Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const DatabaseFailure();
    }
  }
}
