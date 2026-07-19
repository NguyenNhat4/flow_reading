import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/reader_session.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/reading_position.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/repositories/reader_settings_repository.dart';
import 'package:flow_reading/domain/repositories/reading_position_repository.dart';
import 'package:flow_reading/domain/repositories/table_of_contents_repository.dart';

/// Loads the independent sources required for one reader session.
final class LoadReaderSessionUseCase {
  const LoadReaderSessionUseCase({
    required this._bookRepository,
    required this._positionRepository,
    required this._settingsRepository,
    required this._tableOfContentsRepository,
  });

  final BookRepository _bookRepository;
  final ReadingPositionRepository _positionRepository;
  final ReaderSettingsRepository _settingsRepository;
  final TableOfContentsRepository _tableOfContentsRepository;

  Future<ReaderSession> call(String bookId) async {
    final values = await Future.wait<Object?>([
      _bookRepository.loadChapters(bookId),
      _positionRepository.load(bookId),
      _settingsRepository.load(),
      _tableOfContentsRepository.load(bookId),
    ]);
    return ReaderSession(
      chapters: values[0]! as List<Chapter>,
      position: values[1] as ReadingPosition?,
      settings: values[2]! as ReaderSettings,
      tableOfContents: values[3]! as List<TableOfContentsEntry>,
    );
  }
}
