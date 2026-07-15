import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Generates deterministic identifiers from canonical EPUB source data.
abstract final class ContentIdentifiers {
  static String book(Uint8List epubBytes) => _digest('book', epubBytes);

  static String chapter({
    required String bookId,
    required int spineIndex,
    required String sourceHref,
  }) {
    _requireNonNegative(spineIndex, 'spineIndex');
    return _fromParts('chapter', [
      bookId,
      spineIndex,
      _normalizeHref(sourceHref),
    ]);
  }

  static String block({
    required String chapterId,
    required int order,
    required String type,
    required String sourceLocator,
  }) {
    _requireNonNegative(order, 'order');
    return _fromParts('block', [chapterId, order, type, sourceLocator]);
  }

  static String sentence({
    required String blockId,
    required int startOffset,
    required int endOffset,
    required String text,
  }) {
    _validateOffsets(startOffset, endOffset);
    return _fromParts('sentence', [blockId, startOffset, endOffset, text]);
  }

  static String textRange({
    required String bookId,
    required String chapterId,
    required String blockId,
    required int startOffset,
    required int endOffset,
  }) {
    _validateOffsets(startOffset, endOffset);
    return _fromParts('range', [
      bookId,
      chapterId,
      blockId,
      startOffset,
      endOffset,
    ]);
  }

  static String _fromParts(String kind, List<Object> parts) {
    return _digest(kind, utf8.encode(jsonEncode(parts)));
  }

  static String _digest(String kind, List<int> bytes) {
    return '${kind}_${sha256.convert(bytes)}';
  }

  static String _normalizeHref(String href) {
    final normalizedSeparators = href.replaceAll('\\', '/');
    return Uri.parse(normalizedSeparators).normalizePath().toString();
  }

  static void _validateOffsets(int startOffset, int endOffset) {
    _requireNonNegative(startOffset, 'startOffset');
    if (endOffset < startOffset) {
      throw ArgumentError.value(
        endOffset,
        'endOffset',
        'must be greater than or equal to startOffset',
      );
    }
  }

  static void _requireNonNegative(int value, String name) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'must not be negative');
    }
  }
}

/// A layout-independent selection within one canonical source block.
final class StableTextRange {
  StableTextRange({
    required this.bookId,
    required this.chapterId,
    required this.blockId,
    required this.startOffset,
    required this.endOffset,
  }) : id = ContentIdentifiers.textRange(
         bookId: bookId,
         chapterId: chapterId,
         blockId: blockId,
         startOffset: startOffset,
         endOffset: endOffset,
       );

  final String id;
  final String bookId;
  final String chapterId;
  final String blockId;
  final int startOffset;
  final int endOffset;

  Map<String, Object> toJson() => {
    'id': id,
    'bookId': bookId,
    'chapterId': chapterId,
    'blockId': blockId,
    'startOffset': startOffset,
    'endOffset': endOffset,
  };

  factory StableTextRange.fromJson(Map<String, Object?> json) {
    final range = StableTextRange(
      bookId: json['bookId'] as String,
      chapterId: json['chapterId'] as String,
      blockId: json['blockId'] as String,
      startOffset: json['startOffset'] as int,
      endOffset: json['endOffset'] as int,
    );
    final storedId = json['id'];
    if (storedId != null && storedId != range.id) {
      throw const FormatException('Text range ID does not match its content');
    }
    return range;
  }
}
