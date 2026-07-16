import 'package:flow_reading/domain/models/ai_provider_models.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:flow_reading/ui/features/settings/view_models/ai_settings_view_model.dart';
import 'package:flow_reading/ui/features/settings/views/ai_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates a replacement before overwriting the stored key', () async {
    final credentials = _Credentials('existing');
    final provider = _Provider()
      ..validationFailure = const InvalidApiKeyFailure();
    final viewModel = AiSettingsViewModel(
      credentialRepository: credentials,
      provider: provider,
      model: 'gpt-5.6-luna',
    );

    expect(await viewModel.validateAndSave('invalid'), isFalse);
    expect(credentials.key, 'existing');

    provider.validationFailure = null;
    expect(await viewModel.validateAndSave('replacement'), isTrue);
    expect(credentials.key, 'replacement');
  });

  testWidgets('obscures key input and supports save and removal', (
    tester,
  ) async {
    final credentials = _Credentials(null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiSettingsSheet(
            viewModel: AiSettingsViewModel(
              credentialRepository: credentials,
              provider: _Provider(),
              model: 'gpt-5.6-luna',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('ai-api-key-field')),
    );
    expect(field.obscureText, isTrue);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('gpt-5.6-luna'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('ai-api-key-field')),
      'user-secret',
    );
    await tester.tap(find.byKey(const ValueKey('validate-ai-key')));
    await tester.pump();
    expect(credentials.key, 'user-secret');
    expect(find.byKey(const ValueKey('remove-ai-key')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove-ai-key')));
    await tester.pump();
    expect(credentials.key, isNull);
  });
}

final class _Credentials implements AiCredentialRepository {
  _Credentials(this.key);

  String? key;

  @override
  Future<bool> contains(String providerId) async => key != null;

  @override
  Future<void> delete(String providerId) async => key = null;

  @override
  Future<String?> read(String providerId) async => key;

  @override
  Future<void> write({
    required String providerId,
    required String apiKey,
  }) async => key = apiKey;
}

final class _Provider implements AiProvider {
  Object? validationFailure;

  @override
  String get id => 'openai';

  @override
  Future<AiCompletion> complete({
    required String apiKey,
    required AiProviderRequest request,
  }) => throw UnimplementedError();

  @override
  AiStreamOperation stream({
    required String apiKey,
    required AiProviderRequest request,
  }) => throw UnimplementedError();

  @override
  Future<void> validateKey(String apiKey) async {
    if (validationFailure case final failure?) throw failure;
  }
}
