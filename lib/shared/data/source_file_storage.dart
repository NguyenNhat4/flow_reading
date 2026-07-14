import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StagedSource {
  const StagedSource(this.stagedPath, this.finalPath);
  final String stagedPath;
  final String finalPath;
}

class SourceFileStorage {
  SourceFileStorage(this._root);

  final Directory _root;

  static Future<SourceFileStorage> createDefault() async {
    final support = await getApplicationSupportDirectory();
    return SourceFileStorage(Directory(p.join(support.path, 'source_epubs')));
  }

  Future<StagedSource> stage(String bookId, Uint8List bytes) async {
    await _root.create(recursive: true);
    final finalPath = p.join(_root.path, '$bookId.epub');
    final stagedPath = '$finalPath.importing';
    await File(stagedPath).writeAsBytes(bytes, flush: true);
    return StagedSource(stagedPath, finalPath);
  }

  Future<void> commit(StagedSource source) async {
    final target = File(source.finalPath);
    if (await target.exists()) await target.delete();
    await File(source.stagedPath).rename(source.finalPath);
  }

  Future<void> discard(StagedSource source) async {
    for (final path in [source.stagedPath, source.finalPath]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<String?> moveToTrash(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final trashPath = '$sourcePath.deleting';
    await source.rename(trashPath);
    return trashPath;
  }

  Future<void> restoreFromTrash(String trashPath, String sourcePath) async {
    final trash = File(trashPath);
    if (await trash.exists()) await trash.rename(sourcePath);
  }

  Future<void> purgeTrash(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
