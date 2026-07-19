import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:flow_reading/ui/core/ui_failure_mapper.dart';
import 'package:flutter/foundation.dart';

/// Immutable presentation state for user-owned AI credentials.
final class AiSettingsState {
  const AiSettingsState({
    this.isConfigured = false,
    this.isLoading = false,
    this.isValidating = false,
    this.errorMessage,
  });

  final bool isConfigured;
  final bool isLoading;
  final bool isValidating;
  final String? errorMessage;

  AiSettingsState copyWith({
    bool? isConfigured,
    bool? isLoading,
    bool? isValidating,
    Object? errorMessage = _unset,
  }) => AiSettingsState(
    isConfigured: isConfigured ?? this.isConfigured,
    isLoading: isLoading ?? this.isLoading,
    isValidating: isValidating ?? this.isValidating,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
  );
}

const _unset = Object();

/// Presentation state for user-owned AI provider credentials.
final class AiSettingsViewModel extends ChangeNotifier {
  AiSettingsViewModel({
    required this._credentialRepository,
    required this._provider,
    required this.model,
    this._failureMapper = const UiFailureMapper(),
  });

  final AiCredentialRepository _credentialRepository;
  final AiProvider _provider;
  final UiFailureMapper _failureMapper;
  final String model;

  AiSettingsState _state = const AiSettingsState();
  bool _disposed = false;

  String get providerName => 'OpenAI';
  AiSettingsState get state => _state;

  Future<void> load() async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      final configured = await _credentialRepository.contains(_provider.id);
      _setState(_state.copyWith(isConfigured: configured));
    } catch (error) {
      _setState(
        _state.copyWith(
          errorMessage: _failureMapper.message(
            error,
            fallback: 'AI settings could not be loaded.',
          ),
        ),
      );
    } finally {
      _setState(_state.copyWith(isLoading: false));
    }
  }

  Future<bool> validateAndSave(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      _setState(
        _state.copyWith(errorMessage: const InvalidApiKeyFailure().message),
      );
      return false;
    }
    _setState(_state.copyWith(isValidating: true, errorMessage: null));
    try {
      await _provider.validateKey(key);
      await _credentialRepository.write(providerId: _provider.id, apiKey: key);
      _setState(_state.copyWith(isConfigured: true));
      return true;
    } catch (error) {
      _setState(
        _state.copyWith(
          errorMessage: _failureMapper.message(
            error,
            fallback: 'AI settings could not be updated.',
          ),
        ),
      );
      return false;
    } finally {
      _setState(_state.copyWith(isValidating: false));
    }
  }

  Future<bool> removeKey() async {
    _setState(_state.copyWith(errorMessage: null));
    try {
      await _credentialRepository.delete(_provider.id);
      _setState(_state.copyWith(isConfigured: false));
      return true;
    } catch (error) {
      _setState(
        _state.copyWith(
          errorMessage: _failureMapper.message(
            error,
            fallback: 'AI settings could not be updated.',
          ),
        ),
      );
      return false;
    }
  }

  void _setState(AiSettingsState state) {
    _state = state;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
