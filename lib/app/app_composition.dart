import 'package:flow_reading/data/repositories/secure_ai_credential_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_ai_artifact_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_book_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_book_search_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_bookmark_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_highlight_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_note_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_reader_settings_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_reading_position_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_table_of_contents_repository.dart';
import 'package:flow_reading/data/services/android_epub_picker.dart';
import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/data/services/local_book_file_storage.dart';
import 'package:flow_reading/data/services/local_epub_content_parser.dart';
import 'package:flow_reading/data/services/mlkit_book_language_detector.dart';
import 'package:flow_reading/data/services/open_ai_provider.dart';
import 'package:flow_reading/data/services/system_utc_clock.dart';
import 'package:flow_reading/domain/repositories/ai_artifact_repository.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:flow_reading/domain/repositories/book_file_storage.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/repositories/book_search_repository.dart';
import 'package:flow_reading/domain/repositories/bookmark_repository.dart';
import 'package:flow_reading/domain/repositories/epub_picker.dart';
import 'package:flow_reading/domain/repositories/highlight_repository.dart';
import 'package:flow_reading/domain/repositories/note_repository.dart';
import 'package:flow_reading/domain/repositories/reader_settings_repository.dart';
import 'package:flow_reading/domain/repositories/reading_position_repository.dart';
import 'package:flow_reading/domain/repositories/table_of_contents_repository.dart';
import 'package:flow_reading/domain/use_cases/build_ai_context.dart';
import 'package:flow_reading/domain/use_cases/detect_book_language.dart';
import 'package:flow_reading/domain/use_cases/generate_grammar_explanation.dart';
import 'package:flow_reading/domain/use_cases/generate_passage_explanation.dart';
import 'package:flow_reading/domain/use_cases/generate_word_explanation.dart';
import 'package:flow_reading/domain/use_cases/import_book.dart';
import 'package:flow_reading/domain/use_cases/load_reader_session.dart';
import 'package:flow_reading/domain/use_cases/remove_book.dart';
import 'package:flow_reading/domain/use_cases/update_book_language.dart';
import 'package:flow_reading/ui/features/library/view_models/library_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/grammar_explanation_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/passage_explanation_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/word_explanation_view_model.dart';
import 'package:flow_reading/ui/features/settings/view_models/ai_settings_view_model.dart';
import 'package:path_provider/path_provider.dart';

/// Owns application dependencies and creates short-lived feature ViewModels.
final class AppComposition {
  AppComposition._({
    required this._database,
    required this.aiArtifactRepository,
    required this.aiCredentialRepository,
    required this.aiProvider,
    required this.bookRepository,
    required this.bookFileStorage,
    required this.bookmarkRepository,
    required this.bookSearchRepository,
    required this.epubPicker,
    required this.importBook,
    required this.highlightRepository,
    required this.noteRepository,
    required this.removeBook,
    required this.updateBookLanguage,
    required this.positionRepository,
    required this.settingsRepository,
    required this.tableOfContentsRepository,
    required this._generateWordExplanation,
    required this._generatePassageExplanation,
    required this._generateGrammarExplanation,
    required this._loadReaderSession,
    required this._clock,
  });

  static const aiModel = OpenAiProvider.cheapestModel;

  /// Creates the production dependency graph.
  static Future<AppComposition> create() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final database = AppDatabase();
    final bookRepository = SqliteBookRepository(database);
    final bookFileStorage = LocalBookFileStorage(supportDirectory);
    final bookSearchRepository = SqliteBookSearchRepository(database);
    final aiArtifactRepository = SqliteAiArtifactRepository(database);
    final aiCredentialRepository = SecureAiCredentialRepository();
    final aiProvider = OpenAiProvider();
    final contextBuilder = BuildAiContextUseCase(
      searchRepository: bookSearchRepository,
    );
    final languageDetection = DetectBookLanguageUseCase(
      MlKitBookLanguageDetector(),
    );
    final bookmarkRepository = SqliteBookmarkRepository(database);
    final highlightRepository = SqliteHighlightRepository(database);
    final noteRepository = SqliteNoteRepository(database);
    final positionRepository = SqliteReadingPositionRepository(database);
    final settingsRepository = SqliteReaderSettingsRepository(database);
    final tableOfContentsRepository = SqliteTableOfContentsRepository(database);
    const clock = SystemUtcClock();

    return AppComposition._(
      database: database,
      aiArtifactRepository: aiArtifactRepository,
      aiCredentialRepository: aiCredentialRepository,
      aiProvider: aiProvider,
      bookRepository: bookRepository,
      bookFileStorage: bookFileStorage,
      bookmarkRepository: bookmarkRepository,
      bookSearchRepository: bookSearchRepository,
      epubPicker: AndroidEpubPicker(),
      importBook: ImportBookUseCase(
        repository: bookRepository,
        storage: bookFileStorage,
        parser: const LocalEpubContentParser(),
        languageDetection: languageDetection,
      ),
      highlightRepository: highlightRepository,
      noteRepository: noteRepository,
      removeBook: RemoveBookUseCase(
        repository: bookRepository,
        storage: bookFileStorage,
      ),
      updateBookLanguage: UpdateBookLanguageUseCase(bookRepository),
      positionRepository: positionRepository,
      settingsRepository: settingsRepository,
      tableOfContentsRepository: tableOfContentsRepository,
      generateWordExplanation: GenerateWordExplanationUseCase(
        contextBuilder: contextBuilder,
        artifactRepository: aiArtifactRepository,
        credentialRepository: aiCredentialRepository,
        provider: aiProvider,
        model: aiModel,
      ),
      generatePassageExplanation: GeneratePassageExplanationUseCase(
        contextBuilder: contextBuilder,
        artifactRepository: aiArtifactRepository,
        credentialRepository: aiCredentialRepository,
        provider: aiProvider,
        model: aiModel,
      ),
      generateGrammarExplanation: GenerateGrammarExplanationUseCase(
        contextBuilder: contextBuilder,
        artifactRepository: aiArtifactRepository,
        credentialRepository: aiCredentialRepository,
        provider: aiProvider,
        model: aiModel,
      ),
      loadReaderSession: LoadReaderSessionUseCase(
        bookRepository: bookRepository,
        positionRepository: positionRepository,
        settingsRepository: settingsRepository,
        tableOfContentsRepository: tableOfContentsRepository,
      ),
      clock: clock,
    );
  }

  final AppDatabase _database;
  final AiArtifactRepository aiArtifactRepository;
  final AiCredentialRepository aiCredentialRepository;
  final AiProvider aiProvider;
  final BookRepository bookRepository;
  final BookFileStorage bookFileStorage;
  final BookmarkRepository bookmarkRepository;
  final BookSearchRepository bookSearchRepository;
  final EpubPicker epubPicker;
  final ImportBookUseCase importBook;
  final HighlightRepository highlightRepository;
  final NoteRepository noteRepository;
  final RemoveBookUseCase removeBook;
  final UpdateBookLanguageUseCase updateBookLanguage;
  final ReadingPositionRepository positionRepository;
  final ReaderSettingsRepository settingsRepository;
  final TableOfContentsRepository tableOfContentsRepository;
  final GenerateWordExplanationUseCase _generateWordExplanation;
  final GeneratePassageExplanationUseCase _generatePassageExplanation;
  final GenerateGrammarExplanationUseCase _generateGrammarExplanation;
  final LoadReaderSessionUseCase _loadReaderSession;
  final SystemUtcClock _clock;

  LibraryViewModel createLibraryViewModel() => LibraryViewModel(
    repository: bookRepository,
    storage: bookFileStorage,
    picker: epubPicker,
    importBook: importBook,
    removeBook: removeBook,
    updateBookLanguage: updateBookLanguage,
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
    loadSession: _loadReaderSession,
    clock: _clock,
  );

  AiSettingsViewModel createAiSettingsViewModel() => AiSettingsViewModel(
    credentialRepository: aiCredentialRepository,
    provider: aiProvider,
    model: aiModel,
  );

  CreateWordExplanationViewModel get createWordExplanationViewModel =>
      ({required chapters, required selection, required currentPosition}) =>
          WordExplanationViewModel(
            generate: _generateWordExplanation,
            chapters: chapters,
            selection: selection,
            currentPosition: currentPosition,
          );

  CreatePassageExplanationViewModel get createPassageExplanationViewModel =>
      ({required chapters, required selection, required currentPosition}) =>
          PassageExplanationViewModel(
            generate: _generatePassageExplanation,
            chapters: chapters,
            selection: selection,
            currentPosition: currentPosition,
          );

  CreateGrammarExplanationViewModel get createGrammarExplanationViewModel =>
      ({required chapters, required selection, required currentPosition}) =>
          GrammarExplanationViewModel(
            generate: _generateGrammarExplanation,
            chapters: chapters,
            selection: selection,
            currentPosition: currentPosition,
          );

  /// Releases application-scoped resources.
  Future<void> dispose() => _database.close();
}
