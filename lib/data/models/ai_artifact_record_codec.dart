import 'package:flow_reading/domain/models/ai_cache_entry.dart';
import 'package:flow_reading/domain/models/ai_provider_models.dart';

/// Encodes cached AI artifacts independently from SQLite row handling.
final class AiArtifactRecordCodec {
  const AiArtifactRecordCodec._();

  static AiJsonMap encode(AiCacheEntry value) => value.toJson();

  static AiCacheEntry decode(AiJsonMap value) => AiCacheEntry.fromJson(value);
}
