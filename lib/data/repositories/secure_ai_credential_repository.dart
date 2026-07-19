import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores AI provider keys using platform-protected credential storage.
final class SecureAiCredentialRepository implements AiCredentialRepository {
  SecureAiCredentialRepository({FlutterSecureStorage? storage})
    : _storage =
          storage ?? const FlutterSecureStorage(aOptions: androidOptions);

  /// Android encryption settings isolated from other secure application data.
  static const androidOptions = AndroidOptions(
    storageNamespace: 'flow_reading_ai_credentials',
  );

  static const _keyPrefix = 'provider_api_key_';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> contains(String providerId) =>
      _guard(() => _storage.containsKey(key: _storageKey(providerId)));

  @override
  Future<String?> read(String providerId) =>
      _guard(() => _storage.read(key: _storageKey(providerId)));

  @override
  Future<void> write({required String providerId, required String apiKey}) {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'Must not be empty');
    }
    return _guard(
      () => _storage.write(key: _storageKey(providerId), value: apiKey),
    );
  }

  @override
  Future<void> delete(String providerId) =>
      _guard(() => _storage.delete(key: _storageKey(providerId)));

  static String _storageKey(String providerId) {
    final normalized = providerId.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(normalized)) {
      throw ArgumentError.value(
        providerId,
        'providerId',
        'Use letters, numbers, underscores, or hyphens',
      );
    }
    return '$_keyPrefix$normalized';
  }

  static Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on ArgumentError {
      rethrow;
    } catch (_) {
      throw const CredentialStorageFailure();
    }
  }
}
