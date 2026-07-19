import 'package:flow_reading/domain/models/ai_cache_entry.dart';

/// Stores successful AI artifacts for deterministic offline reuse.
abstract interface class AiArtifactRepository {
  Future<AiCacheEntry?> read(String cacheId);

  Future<void> save(AiCacheEntry entry);
}
