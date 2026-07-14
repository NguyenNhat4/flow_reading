import 'dart:io';
import 'dart:typed_data';

import 'package:flow_reading/shared/data/local_database.dart';
import 'package:flow_reading/shared/data/source_file_storage.dart';
import 'package:flow_reading/shared/data/sqlite_book_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/sample_book.dart';

void main() {
  late Directory root;
  late LocalDatabase database;
  late SqliteBookRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow_reading_test_');
    database = LocalDatabase(
      databaseFactoryFfi,
      '${root.path}${Platform.pathSeparator}books.sqlite',
    );
    repository = SqliteBookRepository(
      database,
      SourceFileStorage(
        Directory('${root.path}${Platform.pathSeparator}epubs'),
      ),
    );
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'atomically imports canonical content and untouched source bytes',
    () async {
      final bytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2, 3]);
      await repository.import(sampleBook(), bytes);

      final stored = await repository.getById('book_1');
      expect(stored, isNotNull);
      expect(await File(stored!.sourcePath).readAsBytes(), bytes);
      final db = await database.database;
      expect(
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM canonical_content'),
        ),
        greaterThan(3),
      );
      expect(
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM reading_states'),
        ),
        1,
      );
      expect(
        await repository.getBySourceFingerprint(stored.sourceFingerprint),
        isNotNull,
      );
    },
  );

  test('rejects duplicate source without altering the library', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    await repository.import(sampleBook(), bytes);
    await expectLater(
      repository.import(sampleBook(), bytes),
      throwsA(isA<DuplicateBookException>()),
    );
    final books = await repository.watchLibrary().first;
    expect(books, hasLength(1));
  });

  test('transactional deletion removes canonical rows and source', () async {
    await repository.import(sampleBook(), Uint8List.fromList([1, 2, 3]));
    final path = (await repository.getById('book_1'))!.sourcePath;
    await repository.delete('book_1', deleteAssociatedData: true);

    expect(await repository.getById('book_1'), isNull);
    expect(await File(path).exists(), isFalse);
    final db = await database.database;
    expect(
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM annotations'),
      ),
      0,
    );
  });
}
