import 'package:flow_reading/domain/repositories/ai_artifact_repository.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:flow_reading/domain/repositories/book_file_storage.dart';
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
import 'package:flow_reading/domain/use_cases/build_ai_context.dart';
import 'package:flow_reading/domain/use_cases/generate_passage_explanation.dart';
import 'package:flow_reading/domain/use_cases/generate_grammar_explanation.dart';
import 'package:flow_reading/domain/use_cases/generate_word_explanation.dart';
import 'package:flow_reading/domain/use_cases/remove_book.dart';
import 'package:flow_reading/ui/features/library/view_models/library_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/passage_explanation_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/grammar_explanation_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/word_explanation_view_model.dart';
import 'package:flow_reading/ui/features/settings/view_models/ai_settings_view_model.dart';

/// Domain-facing dependencies made available to the presentation layer.
final class AppDependencies {
  static const aiModel = 'gpt-5.6-luna';

  const AppDependencies({
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
    required this.positionRepository,
    required this.settingsRepository,
    required this.tableOfContentsRepository,
  });

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

  AiSettingsViewModel createAiSettingsViewModel() => AiSettingsViewModel(
    credentialRepository: aiCredentialRepository,
    provider: aiProvider,
    model: aiModel,
  );

  CreateWordExplanationViewModel get createWordExplanationViewModel =>
      ({required chapters, required selection, required currentPosition}) =>
          WordExplanationViewModel(
            generate: GenerateWordExplanationUseCase(
              contextBuilder: BuildAiContextUseCase(
                searchRepository: bookSearchRepository,
              ),
              artifactRepository: aiArtifactRepository,
              credentialRepository: aiCredentialRepository,
              provider: aiProvider,
              model: aiModel,
            ),
            chapters: chapters,
            selection: selection,
            currentPosition: currentPosition,
          );

  CreatePassageExplanationViewModel get createPassageExplanationViewModel =>
      ({required chapters, required selection, required currentPosition}) =>
          PassageExplanationViewModel(
            generate: GeneratePassageExplanationUseCase(
              contextBuilder: BuildAiContextUseCase(
                searchRepository: bookSearchRepository,
              ),
              artifactRepository: aiArtifactRepository,
              credentialRepository: aiCredentialRepository,
              provider: aiProvider,
              model: aiModel,
            ),
            chapters: chapters,
            selection: selection,
            currentPosition: currentPosition,
          );

  CreateGrammarExplanationViewModel get createGrammarExplanationViewModel =>
      ({required chapters, required selection, required currentPosition}) =>
          GrammarExplanationViewModel(
            generate: GenerateGrammarExplanationUseCase(
              contextBuilder: BuildAiContextUseCase(
                searchRepository: bookSearchRepository,
              ),
              artifactRepository: aiArtifactRepository,
              credentialRepository: aiCredentialRepository,
              provider: aiProvider,
              model: aiModel,
            ),
            chapters: chapters,
            selection: selection,
            currentPosition: currentPosition,
          );
}
