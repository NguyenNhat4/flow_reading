import 'package:flow_reading/domain/models/text_anchors.dart';

/// A user-authored note attached to one canonical source range.
final class ReaderNote {
  ReaderNote({
    required this.range,
    required String body,
    required this.createdAt,
    required this.updatedAt,
  }) : id = range.id,
       bookId = range.bookId,
       body = _normalizedBody(body);

  factory ReaderNote.fromJson(JsonMap json) {
    final range = TextAnchor.fromJson(_map(json['range']));
    final note = ReaderNote(
      range: range,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
    if (json['id'] != note.id || json['bookId'] != note.bookId) {
      throw const FormatException('Note identity does not match its range');
    }
    return note;
  }

  final String id;
  final String bookId;
  final TextAnchor range;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  JsonMap toJson() => {
    'id': id,
    'bookId': bookId,
    'range': range.toJson(),
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

String _normalizedBody(String body) {
  final normalized = body.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(body, 'body', 'must not be empty');
  }
  return normalized;
}

JsonMap _map(Object? value) => (value as Map).cast<String, Object?>();
