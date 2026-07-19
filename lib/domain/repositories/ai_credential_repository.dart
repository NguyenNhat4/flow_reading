/// Stores user-owned AI provider credentials outside normal application data.
abstract interface class AiCredentialRepository {
  /// Returns whether a key is stored for [providerId].
  Future<bool> contains(String providerId);

  /// Reads the stored key for [providerId], or `null` when none exists.
  Future<String?> read(String providerId);

  /// Securely stores [apiKey] for [providerId].
  Future<void> write({required String providerId, required String apiKey});

  /// Removes the stored key for [providerId].
  Future<void> delete(String providerId);
}
