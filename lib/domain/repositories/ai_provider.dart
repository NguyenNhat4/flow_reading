import 'package:flow_reading/domain/models/ai_provider_models.dart';

/// Executes AI requests without exposing a provider SDK or transport to UI.
///
/// Implementations must map authentication, quota, rate-limit, connectivity,
/// cancellation, and provider errors to the shared application failure types.
abstract interface class AiProvider {
  /// Stable identifier used for cache and configuration ownership.
  String get id;

  /// Verifies that [apiKey] can access this provider.
  Future<void> validateKey(String apiKey);

  /// Completes one request and returns its final response.
  Future<AiCompletion> complete({
    required String apiKey,
    required AiProviderRequest request,
  });

  /// Starts one cancellable streaming request.
  AiStreamOperation stream({
    required String apiKey,
    required AiProviderRequest request,
  });
}
