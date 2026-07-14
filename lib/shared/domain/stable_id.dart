import 'dart:convert';

import 'package:crypto/crypto.dart';

enum CanonicalNodeType {
  book,
  chapter,
  block,
  paragraph,
  sentence,
  word,
  image,
}

/// Creates IDs from immutable source identity and structural position.
///
/// Viewport size, page number, reader settings, and rendered text are
/// deliberately excluded. The occurrence index disambiguates duplicate text.
abstract final class StableId {
  static const algorithmVersion = 1;

  static String content({
    required String sourceFingerprint,
    required CanonicalNodeType type,
    required String sourceDocumentPath,
    required List<int> structuralPath,
  }) {
    final seed = [
      'v$algorithmVersion',
      sourceFingerprint.toLowerCase(),
      type.name,
      _normalizePath(sourceDocumentPath),
      structuralPath.join('.'),
    ].join('|');
    return '${type.name}_${sha256.convert(utf8.encode(seed)).toString().substring(0, 24)}';
  }

  static String source(List<int> bytes) => sha256.convert(bytes).toString();

  static String _normalizePath(String value) =>
      value.replaceAll('\\', '/').replaceAll(RegExp('/+'), '/').toLowerCase();
}
