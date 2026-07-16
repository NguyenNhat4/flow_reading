import 'package:flow_reading/domain/models/bookmark.dart';

/// Stores bookmarks attached to stable logical reader locations.
abstract interface class BookmarkRepository {
  Future<List<Bookmark>> listForBook(String bookId);

  Future<void> save(Bookmark bookmark);

  Future<void> delete(String bookmarkId);
}
