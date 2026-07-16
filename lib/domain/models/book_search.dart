import 'package:flow_reading/domain/models/text_anchors.dart';

/// One canonical text block stored in the local full-text index.
final class SearchableSegment {
  const SearchableSegment({
    required this.segmentId,
    required this.bookId,
    required this.chapterId,
    required this.blockId,
    required this.plainText,
  });

  final String segmentId;
  final String bookId;
  final String chapterId;
  final String blockId;
  final String plainText;
}

/// One offline in-book search match and its logical reader destination.
final class BookSearchResult {
  const BookSearchResult({
    required this.segment,
    required this.excerpt,
    required this.locator,
  });

  final SearchableSegment segment;
  final String excerpt;
  final ReadingLocator locator;
}
