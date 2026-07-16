import 'package:flow_reading/domain/models/reader_note.dart';

/// Stores notes attached to stable canonical source ranges.
abstract interface class NoteRepository {
  Future<List<ReaderNote>> listForBook(String bookId);

  Future<void> save(ReaderNote note);

  Future<void> delete(String noteId);
}
