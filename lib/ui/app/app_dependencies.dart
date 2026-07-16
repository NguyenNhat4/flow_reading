import 'package:flow_reading/domain/repositories/book_file_storage.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flow_reading/domain/repositories/bookmark_repository.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/repositories/book_search_repository.dart';
import 'package:flow_reading/domain/repositories/epub_picker.dart';
import 'package:flow_reading/domain/repositories/highlight_repository.dart';
import 'package:flow_reading/domain/repositories/note_repository.dart';
import 'package:flow_reading/domain/repositories/reader_settings_repository.dart';
import 'package:flow_reading/domain/repositories/reading_position_repository.dart';
import 'package:flow_reading/domain/repositories/table_of_contents_repository.dart';
import 'package:flow_reading/domain/use_cases/import_book.dart';
import 'package:flow_reading/domain/use_cases/remove_book.dart';
import 'package:flow_reading/ui/features/library/view_models/library_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_view_model.dart';

/// Domain-facing dependencies made available to the presentation layer.
final class AppDependencies {
  const AppDependencies({
    required this.aiCredentialRepository,
    required this.bookRepository,
    required this.bookFileStorage,
    required this.bookmarkRepository,
    required this.bookSearchRepository,
    required this.epubPicker,
    required this.importBook,
    required this.highlightRepository,
    required this.noteRepository,
    required this.removeBook,
    required this.positionRepository,
    required this.settingsRepository,
    required this.tableOfContentsRepository,
  });

  final AiCredentialRepository aiCredentialRepository;
  final BookRepository bookRepository;
  final BookFileStorage bookFileStorage;
  final BookmarkRepository bookmarkRepository;
  final BookSearchRepository bookSearchRepository;
  final EpubPicker epubPicker;
  final ImportBookUseCase importBook;
  final HighlightRepository highlightRepository;
  final NoteRepository noteRepository;
  final RemoveBookUseCase removeBook;
  final ReadingPositionRepository positionRepository;
  final ReaderSettingsRepository settingsRepository;
  final TableOfContentsRepository tableOfContentsRepository;

  LibraryViewModel createLibraryViewModel() => LibraryViewModel(
    repository: bookRepository,
    storage: bookFileStorage,
    picker: epubPicker,
    importBook: importBook,
    removeBook: removeBook,
  );

  ReaderViewModel createReaderViewModel(BookSummary book) => ReaderViewModel(
    book: book,
    bookRepository: bookRepository,
    bookmarkRepository: bookmarkRepository,
    bookSearchRepository: bookSearchRepository,
    positionRepository: positionRepository,
    settingsRepository: settingsRepository,
    highlightRepository: highlightRepository,
    noteRepository: noteRepository,
    tableOfContentsRepository: tableOfContentsRepository,
  );
}
