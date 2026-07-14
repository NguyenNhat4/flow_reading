import 'dart:typed_data';

import 'package:flow_reading/shared/domain/book.dart';

abstract interface class BookRepository {
  Stream<List<Book>> watchLibrary();
  Future<Book?> getById(String id);
  Future<Book?> getBySourceFingerprint(String fingerprint);
  Future<void> import(Book book, Uint8List untouchedSourceBytes);
  Future<void> delete(
    String bookId, {
    required bool deleteAssociatedData,
    Set<AssociatedDataKind> retainedData = const {},
  });
}

enum AssociatedDataKind { highlights, notes, translations, conversations }

abstract interface class ReadingStateRepository {
  Future<ReadingState?> get(String bookId);
  Future<void> save(ReadingState state);
}

abstract interface class AnnotationRepository {
  Stream<List<Annotation>> watchForBook(String bookId);
  Future<void> save(Annotation annotation);
  Future<void> delete(String annotationId);
}

abstract interface class GlossaryRepository {
  Future<List<GlossaryEntry>> forBook(String bookId);
  Future<void> save(GlossaryEntry entry);
}

abstract interface class CachedResultRepository {
  Future<Json?> get(String cacheKey);
  Future<void> put({
    required String cacheKey,
    required String bookId,
    required String kind,
    required Json value,
  });
}

abstract interface class TranslationRepository {
  Future<Json?> get(String cacheKey);
  Future<void> put(
    String cacheKey,
    String bookId,
    String contentId,
    Json value,
  );
}

abstract interface class ConversationRepository {
  Future<List<Json>> forBook(String bookId);
  Future<void> save(Json conversation);
}

abstract interface class PendingSyncRepository {
  Future<List<Json>> pending();
  Future<void> enqueue(Json operation);
  Future<void> markComplete(String operationId);
}

abstract interface class CanonicalBookParser {
  Future<Book> parse(Uint8List sourceBytes, {required String sourcePath});
}
