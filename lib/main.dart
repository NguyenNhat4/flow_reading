import 'package:flow_reading/data/repositories/sqlite_book_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_highlight_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_reader_settings_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_reading_position_repository.dart';
import 'package:flow_reading/data/repositories/sqlite_table_of_contents_repository.dart';
import 'package:flow_reading/data/services/android_epub_picker.dart';
import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/data/services/local_book_file_storage.dart';
import 'package:flow_reading/data/services/local_epub_content_parser.dart';
import 'package:flow_reading/data/services/mlkit_book_language_detector.dart';
import 'package:flow_reading/domain/use_cases/detect_book_language.dart';
import 'package:flow_reading/domain/use_cases/import_book.dart';
import 'package:flow_reading/domain/use_cases/remove_book.dart';
import 'package:flow_reading/ui/app/app_dependencies.dart';
import 'package:flow_reading/ui/app/flow_reading_app.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FlowReadingApp(dependencies: _createDependencies()));
}

Future<AppDependencies> _createDependencies() async {
  final supportDirectory = await getApplicationSupportDirectory();
  final database = AppDatabase();
  final repository = SqliteBookRepository(database);
  final storage = LocalBookFileStorage(supportDirectory);
  final languageDetection = DetectBookLanguageUseCase(
    MlKitBookLanguageDetector(),
  );
  return AppDependencies(
    bookRepository: repository,
    bookFileStorage: storage,
    epubPicker: AndroidEpubPicker(),
    importBook: ImportBookUseCase(
      repository: repository,
      storage: storage,
      parser: const LocalEpubContentParser(),
      languageDetection: languageDetection,
    ),
    highlightRepository: SqliteHighlightRepository(database),
    removeBook: RemoveBookUseCase(repository: repository, storage: storage),
    positionRepository: SqliteReadingPositionRepository(database),
    settingsRepository: SqliteReaderSettingsRepository(database),
    tableOfContentsRepository: SqliteTableOfContentsRepository(database),
  );
}
