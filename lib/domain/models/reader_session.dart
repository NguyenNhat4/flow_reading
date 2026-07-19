import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/reading_position.dart';

/// Immutable domain data needed to open a reader session.
final class ReaderSession {
  ReaderSession({
    required List<Chapter> chapters,
    required List<TableOfContentsEntry> tableOfContents,
    required this.settings,
    this.position,
  }) : chapters = List.unmodifiable(chapters),
       tableOfContents = List.unmodifiable(tableOfContents);

  final List<Chapter> chapters;
  final List<TableOfContentsEntry> tableOfContents;
  final ReaderSettings settings;
  final ReadingPosition? position;
}
