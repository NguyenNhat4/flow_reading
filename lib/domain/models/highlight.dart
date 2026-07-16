import 'package:flow_reading/domain/models/text_anchors.dart';

/// A persistent visual marker attached to one canonical source range.
final class Highlight {
  Highlight({
    required this.range,
    required this.createdAt,
    required this.updatedAt,
  }) : id = range.id,
       bookId = range.bookId;

  factory Highlight.fromJson(JsonMap json) {
    final range = TextAnchor.fromJson(_map(json['range']));
    final highlight = Highlight(
      range: range,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
    if (json['id'] != highlight.id || json['bookId'] != highlight.bookId) {
      throw const FormatException(
        'Highlight identity does not match its range',
      );
    }
    return highlight;
  }

  final String id;
  final String bookId;
  final TextAnchor range;
  final DateTime createdAt;
  final DateTime updatedAt;

  JsonMap toJson() => {
    'id': id,
    'bookId': bookId,
    'range': range.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

JsonMap _map(Object? value) => (value as Map).cast<String, Object?>();
