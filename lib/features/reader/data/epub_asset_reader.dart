import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class EpubAssetReader {
  static final Map<String, Uint8List> _cache = {};

  static Future<Uint8List?> load(String sourcePath, String assetPath) async {
    final key = '$sourcePath::$assetPath';
    final cached = _cache[key];
    if (cached != null) return cached;
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    try {
      final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
      final normalized = assetPath.replaceAll('\\', '/');
      final entry = archive.files
          .where((value) => value.name.replaceAll('\\', '/') == normalized)
          .firstOrNull;
      final bytes = entry?.readBytes();
      if (bytes != null) _cache[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
