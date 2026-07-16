import 'dart:io';

import 'package:flow_reading/platform/app_database.dart';
import 'package:flow_reading/platform/sqlite_reader_settings_repository.dart';
import 'package:flow_reading/settings/reader_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory root;
  late AppDatabase database;
  late SqliteReaderSettingsRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow-reader-settings-');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${root.path}/settings.db',
    );
    repository = SqliteReaderSettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('missing preferences load device defaults', () async {
    expect(await repository.load(), ReaderSettings.defaults);
  });

  test('saved preferences replace the singleton and survive reopen', () async {
    await repository.save(ReaderSettings(fontSize: 20));
    final expected = ReaderSettings(
      fontFamily: 'Literata',
      fontSize: 22,
      theme: ReaderTheme.paper,
      languageMode: ReaderLanguageMode.mixed,
    );
    await repository.save(expected);
    await database.close();

    expect(await repository.load(), expected);
    final sqlite = await database.open();
    expect(await sqlite.query('reader_preferences'), hasLength(1));
  });

  test('malformed stored preferences fall back to defaults', () async {
    final sqlite = await database.open();
    await sqlite.insert('reader_preferences', {
      'id': 1,
      'preferences_json': '{invalid',
      'updated_at': DateTime.utc(2026).toIso8601String(),
    });

    expect(await repository.load(), ReaderSettings.defaults);
  });
}
