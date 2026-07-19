import 'dart:async';

import 'package:flow_reading/domain/models/ai_provider_models.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI provider contract', () {
    test('keeps prompts and API keys outside the provider request model', () {
      final request = AiProviderRequest(
        model: 'reader-model',
        instructions: 'Explain only the supplied passage.',
        input: 'Selected source text.',
        responseFormat: AiJsonResponseFormat(
          name: 'explanation',
          schema: {
            'type': 'object',
            'properties': {
              'explanation': {'type': 'string'},
            },
            'required': ['explanation'],
          },
        ),
        maxOutputTokens: 400,
      );

      expect(request.model, 'reader-model');
      expect(request.instructions, contains('supplied passage'));
      expect(request.input, 'Selected source text.');
      expect(request.responseFormat, isA<AiJsonResponseFormat>());
      expect(request.maxOutputTokens, 400);
    });

    test('supports validation and non-streaming completion', () async {
      final provider = _FakeAiProvider();
      final request = AiProviderRequest(
        model: 'reader-model',
        instructions: 'Explain the passage.',
        input: 'A short passage.',
      );

      await provider.validateKey('user-key');
      final completion = await provider.complete(
        apiKey: 'user-key',
        request: request,
      );

      expect(provider.validatedKey, 'user-key');
      expect(completion.text, 'Completed: A short passage.');
      expect(completion.providerId, provider.id);
      expect(completion.model, request.model);
    });

    test('streams deltas, a completion, and supports cancellation', () async {
      final provider = _FakeAiProvider();
      final operation = provider.stream(
        apiKey: 'user-key',
        request: AiProviderRequest(
          model: 'reader-model',
          instructions: 'Explain the passage.',
          input: 'Passage.',
        ),
      );
      final events = <AiStreamEvent>[];
      final done = operation.events.toList().then(events.addAll);

      provider.streamController
        ..add(const AiTextDelta('First '))
        ..add(const AiTextDelta('sentence.'))
        ..add(
          AiStreamCompleted(
            AiCompletion(
              text: 'First sentence.',
              providerId: provider.id,
              model: 'reader-model',
            ),
          ),
        );
      await provider.streamController.close();
      await done;
      await operation.cancel();

      expect(events.whereType<AiTextDelta>().map((event) => event.text), [
        'First ',
        'sentence.',
      ]);
      expect(events.last, isA<AiStreamCompleted>());
      expect(provider.cancelled, isTrue);
    });

    test('shared failures represent provider error mapping outcomes', () {
      const failures = <AppFailure>[
        InvalidApiKeyFailure(),
        AiRateLimitFailure(retryAfter: Duration(seconds: 5)),
        AiQuotaFailure(),
        NetworkFailure(),
        AiRequestCancelledFailure(),
        AiProviderFailure(),
      ];

      expect(
        failures.map((failure) => failure.message),
        everyElement(isNotEmpty),
      );
      expect(
        (failures[1] as AiRateLimitFailure).retryAfter,
        const Duration(seconds: 5),
      );
    });
  });

  group('AI provider request validation', () {
    test('rejects empty required values and invalid token limits', () {
      expect(
        () => AiProviderRequest(
          model: '',
          instructions: 'Instructions',
          input: 'Input',
        ),
        throwsArgumentError,
      );
      expect(
        () =>
            AiProviderRequest(model: 'model', instructions: '', input: 'Input'),
        throwsArgumentError,
      );
      expect(
        () => AiProviderRequest(
          model: 'model',
          instructions: 'Instructions',
          input: '',
        ),
        throwsArgumentError,
      );
      expect(
        () => AiProviderRequest(
          model: 'model',
          instructions: 'Instructions',
          input: 'Input',
          maxOutputTokens: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}

final class _FakeAiProvider implements AiProvider {
  final streamController = StreamController<AiStreamEvent>();
  String? validatedKey;
  bool cancelled = false;

  @override
  String get id => 'fake';

  @override
  Future<void> validateKey(String apiKey) async {
    validatedKey = apiKey;
  }

  @override
  Future<AiCompletion> complete({
    required String apiKey,
    required AiProviderRequest request,
  }) async => AiCompletion(
    text: 'Completed: ${request.input}',
    providerId: id,
    model: request.model,
  );

  @override
  AiStreamOperation stream({
    required String apiKey,
    required AiProviderRequest request,
  }) => _FakeStreamOperation(
    events: streamController.stream,
    onCancel: () async {
      cancelled = true;
    },
  );
}

final class _FakeStreamOperation implements AiStreamOperation {
  const _FakeStreamOperation({required this.events, required this.onCancel});

  @override
  final Stream<AiStreamEvent> events;
  final Future<void> Function() onCancel;

  @override
  Future<void> cancel() => onCancel();
}
