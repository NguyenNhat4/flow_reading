import 'package:flow_reading/domain/models/highlight.dart';

/// Stores highlights attached to stable canonical source ranges.
abstract interface class HighlightRepository {
  Future<List<Highlight>> listForBook(String bookId);

  Future<void> save(Highlight highlight);

  Future<void> delete(String highlightId);
}
