import 'dart:io';
import 'dart:typed_data';

import 'package:flow_reading/books/book_file_storage.dart';
import 'package:flow_reading/platform/local_book_file_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late LocalBookFileStorage storage;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flow-reading-storage-');
    storage = LocalBookFileStorage(root);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('copies unchanged bytes and associates them with the book ID', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final result = await storage.stageOriginal(bytes) as StagedBookFiles;

    expect(result.originalFilePath, contains(result.bookId));
    expect(
      await File('${result.stagingDirectory}/original.epub').readAsBytes(),
      bytes,
    );

    await storage.commit(result);
    expect(await File(result.originalFilePath).readAsBytes(), bytes);
    expect(await storage.contains(result.bookId), isTrue);
  });

  test('detects duplicate content without replacing stored files', () async {
    final bytes = Uint8List.fromList([4, 3, 2, 1]);
    final first = await storage.stageOriginal(bytes) as StagedBookFiles;
    await storage.commit(first);

    final duplicate = await storage.stageOriginal(bytes);

    expect(duplicate, isA<DuplicateBookFiles>());
    expect(duplicate.bookId, first.bookId);
    expect(await File(first.originalFilePath).readAsBytes(), bytes);
  });

  test('rollback removes only incomplete copied data', () async {
    final staged =
        await storage.stageOriginal(Uint8List.fromList([9, 8, 7]))
            as StagedBookFiles;

    await storage.rollback(staged);

    expect(await Directory(staged.stagingDirectory).exists(), isFalse);
    expect(await storage.contains(staged.bookId), isFalse);
  });

  test('stages assets and deletes a committed book', () async {
    final staged =
        await storage.stageOriginal(Uint8List.fromList([5, 5, 5]))
            as StagedBookFiles;
    final assetPath = await storage.stageAsset(
      staged,
      assetId: 'asset_id',
      extension: '.JPG',
      bytes: Uint8List.fromList([6, 7]),
    );
    await storage.commit(staged);

    expect(await File(assetPath).readAsBytes(), [6, 7]);
    await storage.delete(staged.bookId);
    expect(await storage.contains(staged.bookId), isFalse);
  });

  test('stages removal and can restore the active book directory', () async {
    final imported =
        await storage.stageOriginal(Uint8List.fromList([2, 4, 6]))
            as StagedBookFiles;
    await storage.commit(imported);

    final removal = await storage.stageBookRemoval(imported.bookId);
    expect(await storage.contains(imported.bookId), isFalse);

    await storage.rollbackBookRemoval(removal);
    expect(await storage.contains(imported.bookId), isTrue);
    expect(await File(imported.originalFilePath).readAsBytes(), [2, 4, 6]);
  });

  test('committing staged removal permanently deletes book files', () async {
    final imported =
        await storage.stageOriginal(Uint8List.fromList([1, 3, 5]))
            as StagedBookFiles;
    await storage.commit(imported);

    final removal = await storage.stageBookRemoval(imported.bookId);
    await storage.commitBookRemoval(removal);

    expect(await storage.contains(imported.bookId), isFalse);
    expect(await Directory(removal.stagingDirectory!).exists(), isFalse);
  });
}
