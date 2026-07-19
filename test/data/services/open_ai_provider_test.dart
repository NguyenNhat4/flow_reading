import 'dart:async';
import 'dart:convert';

import 'package:flow_reading/data/services/open_ai_provider.dart';
import 'package:flow_reading/domain/models/ai_provider_models.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenAI key validation', () {
    test('verifies authentication and default-model availability', () async {
      late http.Request captured;
      final provider = OpenAiProvider(
        clientFactory: () => MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'object': 'list',
              'data': [
                {'id': 'gpt-5-nano'},
              ],
            }),
            200,
          );
        }),
      );

      await provider.validateKey(' user-owned-key ');

      expect(captured.method, 'GET');
      expect(captured.url.path, '/v1/models');
      expect(captured.headers['authorization'], 'Bearer user-owned-key');
    });

    test('maps invalid authentication to InvalidApiKeyFailure', () async {
      final provider = _providerReturning(401, body: _error('invalid_api_key'));

      await expectLater(
        provider.validateKey('invalid-key'),
        throwsA(isA<InvalidApiKeyFailure>()),
      );
    });

    test('rejects a key without access to the configured model', () async {
      final provider = OpenAiProvider(
        clientFactory: () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'object': 'list',
              'data': [
                {'id': 'another-model'},
              ],
            }),
            200,
          ),
        ),
      );

      await expectLater(
        provider.validateKey('valid-key'),
        throwsA(isA<AiProviderFailure>()),
      );
    });
  });

  group('OpenAI completion', () {
    test(
      'sends a non-stored Responses API request and parses output',
      () async {
        late Map<String, Object?> requestJson;
        final provider = OpenAiProvider(
          clientFactory: () => MockClient((request) async {
            requestJson = (jsonDecode(request.body) as Map)
                .cast<String, Object?>();
            return http.Response(
              _completionResponse(text: 'A contextual explanation.'),
              200,
            );
          }),
        );
        final request = AiProviderRequest(
          model: 'gpt-5-nano',
          instructions: 'Explain the selected source.',
          input: 'Source text.',
          maxOutputTokens: 500,
        );

        final completion = await provider.complete(
          apiKey: 'user-key',
          request: request,
        );

        expect(requestJson['store'], isFalse);
        expect(requestJson['stream'], isFalse);
        expect(requestJson['instructions'], request.instructions);
        expect(requestJson['input'], request.input);
        expect(requestJson['max_output_tokens'], 500);
        expect(requestJson, isNot(contains('api_key')));
        expect(completion.text, 'A contextual explanation.');
        expect(completion.providerId, 'openai');
        expect(completion.model, 'gpt-5-nano');
      },
    );

    test('maps structured output to text.format JSON schema', () async {
      late Map<String, Object?> requestJson;
      final provider = OpenAiProvider(
        clientFactory: () => MockClient((request) async {
          requestJson = (jsonDecode(request.body) as Map)
              .cast<String, Object?>();
          return http.Response(
            _completionResponse(text: '{"meaning":"contextual"}'),
            200,
          );
        }),
      );

      await provider.complete(
        apiKey: 'user-key',
        request: AiProviderRequest(
          model: 'gpt-5-nano',
          instructions: 'Return structured output.',
          input: 'Word.',
          responseFormat: AiJsonResponseFormat(
            name: 'word_explanation',
            schema: {
              'type': 'object',
              'properties': {
                'meaning': {'type': 'string'},
              },
              'required': ['meaning'],
              'additionalProperties': false,
            },
          ),
        ),
      );

      final text = (requestJson['text'] as Map).cast<String, Object?>();
      final format = (text['format'] as Map).cast<String, Object?>();
      expect(format['type'], 'json_schema');
      expect(format['name'], 'word_explanation');
      expect(format['strict'], isTrue);
      expect(format['schema'], isA<Map>());
    });

    test('maps rate limits, quota, and connectivity failures', () async {
      final rateLimited = _providerReturning(
        429,
        body: _error('rate_limit_exceeded'),
        headers: {'retry-after': '7'},
      );
      final exhausted = _providerReturning(
        429,
        body: _error('insufficient_quota'),
      );
      final offline = OpenAiProvider(
        clientFactory: () =>
            MockClient((_) async => throw http.ClientException('offline')),
      );
      final request = _request();

      await expectLater(
        rateLimited.complete(apiKey: 'key', request: request),
        throwsA(
          isA<AiRateLimitFailure>().having(
            (failure) => failure.retryAfter,
            'retryAfter',
            const Duration(seconds: 7),
          ),
        ),
      );
      await expectLater(
        exhausted.complete(apiKey: 'key', request: request),
        throwsA(isA<AiQuotaFailure>()),
      );
      await expectLater(
        offline.complete(apiKey: 'key', request: request),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('OpenAI streaming', () {
    test('parses text deltas and the terminal response', () async {
      final sse = [
        'event: response.created',
        'data: ${jsonEncode({'type': 'response.created'})}',
        '',
        'event: response.output_text.delta',
        'data: ${jsonEncode({'type': 'response.output_text.delta', 'delta': 'First '})}',
        '',
        'event: response.output_text.delta',
        'data: ${jsonEncode({'type': 'response.output_text.delta', 'delta': 'sentence.'})}',
        '',
        'event: response.completed',
        'data: ${jsonEncode({
          'type': 'response.completed',
          'response': {'status': 'completed', 'model': 'gpt-5-nano'},
        })}',
        '',
      ].join('\n');
      final provider = OpenAiProvider(
        clientFactory: () => MockClient.streaming(
          (_, _) async =>
              http.StreamedResponse(Stream.value(utf8.encode(sse)), 200),
        ),
      );

      final events = await provider
          .stream(apiKey: 'key', request: _request())
          .events
          .toList();

      expect(events.whereType<AiTextDelta>().map((event) => event.text), [
        'First ',
        'sentence.',
      ]);
      final completed = events.whereType<AiStreamCompleted>().single;
      expect(completed.completion.text, 'First sentence.');
    });

    test('cancels an in-flight streamed request', () async {
      final client = _AbortAwareClient();
      final provider = OpenAiProvider(clientFactory: () => client);
      final operation = provider.stream(apiKey: 'key', request: _request());
      final eventsFuture = operation.events.toList();
      await client.requestStarted.future;

      await operation.cancel();
      final events = await eventsFuture;

      expect(client.abortObserved, isTrue);
      expect(events, [isA<AiStreamCancelled>()]);
    });

    test('emits a typed failure for streamed provider errors', () async {
      final sse = [
        'event: error',
        'data: ${jsonEncode({
          'type': 'error',
          'error': {'code': 'rate_limit_exceeded'},
        })}',
        '',
      ].join('\n');
      final provider = OpenAiProvider(
        clientFactory: () => MockClient.streaming(
          (_, _) async =>
              http.StreamedResponse(Stream.value(utf8.encode(sse)), 200),
        ),
      );

      final events = await provider
          .stream(apiKey: 'key', request: _request())
          .events
          .toList();

      expect(events.single, isA<AiStreamFailed>());
      expect(
        (events.single as AiStreamFailed).failure,
        isA<AiRateLimitFailure>(),
      );
    });
  });
}

OpenAiProvider _providerReturning(
  int statusCode, {
  required String body,
  Map<String, String> headers = const {},
}) => OpenAiProvider(
  clientFactory: () => MockClient(
    (_) async => http.Response(body, statusCode, headers: headers),
  ),
);

AiProviderRequest _request() => AiProviderRequest(
  model: 'gpt-5-nano',
  instructions: 'Explain the passage.',
  input: 'Passage text.',
);

String _error(String code) => jsonEncode({
  'error': {'code': code, 'message': 'Sanitized test error'},
});

String _completionResponse({required String text}) => jsonEncode({
  'id': 'response-id',
  'status': 'completed',
  'model': 'gpt-5-nano',
  'output': [
    {
      'type': 'message',
      'status': 'completed',
      'content': [
        {'type': 'output_text', 'text': text, 'annotations': []},
      ],
    },
  ],
});

final class _AbortAwareClient extends http.BaseClient {
  final requestStarted = Completer<void>();
  bool abortObserved = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!requestStarted.isCompleted) requestStarted.complete();
    final controller = StreamController<List<int>>();
    if (request case http.Abortable(:final abortTrigger?)) {
      unawaited(
        abortTrigger.whenComplete(() {
          abortObserved = true;
          controller
            ..addError(http.RequestAbortedException(request.url))
            ..close();
        }),
      );
    }
    return http.StreamedResponse(controller.stream, 200);
  }
}
