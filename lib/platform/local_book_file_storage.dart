import 'dart:io';
import 'dart:typed_data';

import 'package:flow_reading/books/book_file_storage.dart';
import 'package:flow_reading/books/book_removal_service.dart';
import 'package:flow_reading/books/content_identifiers.dart';
import 'package:flow_reading/shared/app_failure.dart';

final class LocalBookFileStorage
    implements BookFileStorage, BookRemovalStorage {
  LocalBookFileStorage(this.applicationSupportDirectory);

  final Directory applicationSupportDirectory;

  Directory get _booksDirectory => Directory(
    '${applicationSupportDirectory.path}${Platform.pathSeparator}books',
  );

  @override
  Future<BookFileStageResult> stageOriginal(Uint8List bytes) async {
    final bookId = ContentIdentifiers.book(bytes);
    final finalDirectory = _bookDirectory(bookId);
    if (await finalDirectory.exists()) {
      return DuplicateBookFiles(bookId: bookId);
    }

    final stagingDirectory = Directory(
      '${_booksDirectory.path}${Platform.pathSeparator}'
      '.tmp-$bookId-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await stagingDirectory.create(recursive: true);
      final stagedOriginal = File(
        '${stagingDirectory.path}${Platform.pathSeparator}original.epub',
      );
      await stagedOriginal.writeAsBytes(bytes, flush: true);
      return StagedBookFiles(
        bookId: bookId,
        stagingDirectory: stagingDirectory.path,
        finalDirectory: finalDirectory.path,
        originalFilePath:
            '${finalDirectory.path}${Platform.pathSeparator}original.epub',
      );
    } on FileSystemException catch (error) {
      await _deleteIfPresent(stagingDirectory);
      throw FileSystemFailure(message: 'The EPUB could not be copied: $error');
    }
  }

  @override
  Future<String> stageAsset(
    StagedBookFiles stage, {
    required String assetId,
    required String extension,
    required Uint8List bytes,
  }) async {
    final safeExtension = extension.toLowerCase().replaceAll(
      RegExp('[^a-z0-9]'),
      '',
    );
    final fileName = safeExtension.isEmpty
        ? assetId
        : '$assetId.$safeExtension';
    try {
      final assetDirectory = Directory(
        '${stage.stagingDirectory}${Platform.pathSeparator}assets',
      );
      await assetDirectory.create(recursive: true);
      await File(
        '${assetDirectory.path}${Platform.pathSeparator}$fileName',
      ).writeAsBytes(bytes, flush: true);
      return '${stage.finalDirectory}${Platform.pathSeparator}'
          'assets${Platform.pathSeparator}$fileName';
    } on FileSystemException catch (error) {
      throw FileSystemFailure(
        message: 'A book asset could not be saved: $error',
      );
    }
  }

  @override
  Future<void> commit(StagedBookFiles stage) async {
    final stagingDirectory = Directory(stage.stagingDirectory);
    final finalDirectory = Directory(stage.finalDirectory);
    try {
      if (await finalDirectory.exists()) {
        throw const FileSystemFailure(
          message: 'This EPUB has already been imported.',
        );
      }
      await stagingDirectory.rename(finalDirectory.path);
    } on FileSystemFailure {
      rethrow;
    } on FileSystemException catch (error) {
      throw FileSystemFailure(
        message: 'The imported book could not be finalized: $error',
      );
    }
  }

  @override
  Future<void> rollback(StagedBookFiles stage) async {
    try {
      await _deleteIfPresent(Directory(stage.stagingDirectory));
    } on FileSystemException catch (error) {
      throw FileSystemFailure(
        message: 'Incomplete import data could not be removed: $error',
      );
    }
  }

  @override
  Future<void> delete(String bookId) async {
    try {
      await _deleteIfPresent(_bookDirectory(bookId));
    } on FileSystemException catch (error) {
      throw FileSystemFailure(
        message: 'The stored book could not be removed: $error',
      );
    }
  }

  @override
  Future<StagedBookRemoval> stageBookRemoval(String bookId) async {
    final activeDirectory = _bookDirectory(bookId);
    if (!await activeDirectory.exists()) {
      return StagedBookRemoval(bookId: bookId);
    }
    final stagingDirectory = Directory(
      '${_booksDirectory.path}${Platform.pathSeparator}'
      '.removing-$bookId-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await activeDirectory.rename(stagingDirectory.path);
      return StagedBookRemoval(
        bookId: bookId,
        activeDirectory: activeDirectory.path,
        stagingDirectory: stagingDirectory.path,
      );
    } on FileSystemException catch (error) {
      throw FileSystemFailure(
        message: 'The stored book could not be prepared for removal: $error',
      );
    }
  }

  @override
  Future<void> commitBookRemoval(StagedBookRemoval stage) async {
    final stagingPath = stage.stagingDirectory;
    if (stagingPath == null) return;
    try {
      await _deleteIfPresent(Directory(stagingPath));
    } on FileSystemException catch (error) {
      throw FileSystemFailure(
        message: 'The removed book files could not be finalized: $error',
      );
    }
  }

  @override
  Future<void> rollbackBookRemoval(StagedBookRemoval stage) async {
    final activePath = stage.activeDirectory;
    final stagingPath = stage.stagingDirectory;
    if (activePath == null || stagingPath == null) return;
    try {
      final stagingDirectory = Directory(stagingPath);
      if (await stagingDirectory.exists()) {
        await stagingDirectory.rename(activePath);
      }
    } on FileSystemException catch (error) {
      throw FileSystemFailure(
        message: 'The stored book could not be restored: $error',
      );
    }
  }

  @override
  Future<bool> contains(String bookId) => _bookDirectory(bookId).exists();

  @override
  Future<Uint8List?> readBytes(String localPath) async {
    try {
      final file = File(localPath);
      return await file.exists() ? file.readAsBytes() : null;
    } on FileSystemException catch (error) {
      throw FileSystemFailure(
        message: 'A book asset could not be read: $error',
      );
    }
  }

  Directory _bookDirectory(String bookId) =>
      Directory('${_booksDirectory.path}${Platform.pathSeparator}$bookId');

  static Future<void> _deleteIfPresent(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
