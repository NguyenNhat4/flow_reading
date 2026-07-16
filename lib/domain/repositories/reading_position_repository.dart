import 'package:flow_reading/domain/models/reading_position.dart';

/// Loads and saves stable logical reading positions.
abstract interface class ReadingPositionRepository {
  Future<ReadingPosition?> load(String bookId);

  Future<void> save(ReadingPosition position);
}
