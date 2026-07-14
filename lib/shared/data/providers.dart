import 'package:flow_reading/shared/data/local_database.dart';
import 'package:flow_reading/shared/data/source_file_storage.dart';
import 'package:flow_reading/shared/data/sqlite_book_repository.dart';
import 'package:flow_reading/shared/data/sqlite_reading_repositories.dart';
import 'package:flow_reading/features/import/application/epub_import_service.dart';
import 'package:flow_reading/features/import/data/epub_parser.dart';
import 'package:flow_reading/features/import/domain/language_detection.dart';
import 'package:flow_reading/shared/domain/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localDatabaseProvider = FutureProvider<LocalDatabase>((ref) async {
  final database = await LocalDatabase.createDefault();
  ref.onDispose(database.close);
  return database;
});

final sourceFileStorageProvider = FutureProvider<SourceFileStorage>(
  (ref) => SourceFileStorage.createDefault(),
);

final bookRepositoryProvider = FutureProvider<BookRepository>((ref) async {
  final database = await ref.watch(localDatabaseProvider.future);
  final sourceStorage = await ref.watch(sourceFileStorageProvider.future);
  return SqliteBookRepository(database, sourceStorage);
});

final readingStateRepositoryProvider = FutureProvider<ReadingStateRepository>((
  ref,
) async {
  return SqliteReadingStateRepository(
    await ref.watch(localDatabaseProvider.future),
  );
});

final annotationRepositoryProvider = FutureProvider<AnnotationRepository>((
  ref,
) async {
  return SqliteAnnotationRepository(
    await ref.watch(localDatabaseProvider.future),
  );
});

final languageDetectionProvider = Provider<LanguageDetectionService>(
  (ref) => const HeuristicLanguageDetectionService(),
);

final canonicalBookParserProvider = Provider<CanonicalBookParser>(
  (ref) => EpubParser(languageDetector: ref.watch(languageDetectionProvider)),
);

final epubPickerProvider = Provider<EpubPicker>(
  (ref) => const AndroidEpubPicker(),
);

final epubImportServiceProvider = FutureProvider<EpubImportService>((
  ref,
) async {
  return EpubImportService(
    picker: ref.watch(epubPickerProvider),
    parser: ref.watch(canonicalBookParserProvider),
    repository: await ref.watch(bookRepositoryProvider.future),
  );
});
