import 'package:flow_reading/domain/models/text_anchors.dart';

/// A durable logical reader location independent of visual page boundaries.
final class Bookmark {
  Bookmark({required this.locator, required this.createdAt})
    : id = locator.anchor.id,
      bookId = locator.anchor.bookId {
    if (locator.anchor.startOffset != locator.anchor.endOffset) {
      throw ArgumentError.value(
        locator.anchor,
        'locator',
        'bookmark anchors must be collapsed',
      );
    }
  }

  factory Bookmark.fromJson(JsonMap json) {
    final locator = ReadingLocator.fromJson(_map(json['locator']));
    final bookmark = Bookmark(
      locator: locator,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
    if (json['id'] != bookmark.id || json['bookId'] != bookmark.bookId) {
      throw const FormatException(
        'Bookmark identity does not match its locator',
      );
    }
    return bookmark;
  }

  final String id;
  final String bookId;
  final ReadingLocator locator;
  final DateTime createdAt;

  JsonMap toJson() => {
    'id': id,
    'bookId': bookId,
    'locator': locator.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

JsonMap _map(Object? value) => (value as Map).cast<String, Object?>();
