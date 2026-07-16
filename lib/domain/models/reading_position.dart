import 'package:flow_reading/domain/models/text_anchors.dart';

/// A persisted logical position in canonical book content.
final class ReadingPosition {
  const ReadingPosition({
    required this.bookId,
    required this.locator,
    required this.updatedAt,
  });

  final String bookId;
  final ReadingLocator locator;
  final DateTime updatedAt;
}
