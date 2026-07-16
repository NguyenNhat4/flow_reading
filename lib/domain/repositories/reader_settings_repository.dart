import 'package:flow_reading/domain/models/reader_settings.dart';

/// Persists device-global reader preferences.
abstract interface class ReaderSettingsRepository {
  Future<ReaderSettings> load();

  Future<void> save(ReaderSettings settings);
}
