import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:flutter/foundation.dart';

/// Presentation state for user-owned AI provider credentials.
final class AiSettingsViewModel extends ChangeNotifier {
  AiSettingsViewModel({
    required AiCredentialRepository credentialRepository,
    required AiProvider provider,
    required String model,
  }) : this._(credentialRepository, provider, model);

  AiSettingsViewModel._(this._credentialRepository, this._provider, this.model);

  final AiCredentialRepository _credentialRepository;
  final AiProvider _provider;
  final String model;

  bool _isConfigured = false;
  bool _isLoading = false;
  bool _isValidating = false;
  String? _errorMessage;
  bool _disposed = false;

  String get providerName => 'OpenAI';
  bool get isConfigured => _isConfigured;
  bool get isLoading => _isLoading;
  bool get isValidating => _isValidating;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      _isConfigured = await _credentialRepository.contains(_provider.id);
    } catch (error) {
      _errorMessage = _message(error);
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<bool> validateAndSave(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      _errorMessage = const InvalidApiKeyFailure().message;
      _notify();
      return false;
    }
    _isValidating = true;
    _errorMessage = null;
    _notify();
    try {
      await _provider.validateKey(key);
      await _credentialRepository.write(providerId: _provider.id, apiKey: key);
      _isConfigured = true;
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _isValidating = false;
      _notify();
    }
  }

  Future<bool> removeKey() async {
    _errorMessage = null;
    try {
      await _credentialRepository.delete(_provider.id);
      _isConfigured = false;
      _notify();
      return true;
    } catch (error) {
      _errorMessage = _message(error);
      _notify();
      return false;
    }
  }

  static String _message(Object error) => switch (error) {
    AppFailure(:final message) => message,
    _ => 'AI settings could not be updated.',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
