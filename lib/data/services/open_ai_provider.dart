import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flow_reading/domain/models/ai_provider_models.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:http/http.dart' as http;

typedef HttpClientFactory = http.Client Function();

/// OpenAI Responses API adapter using a user-owned credential.
final class OpenAiProvider implements AiProvider {
  static const cheapestModel = 'gpt-5-nano';

  OpenAiProvider({
    HttpClientFactory? clientFactory,
    Uri? baseUri,
    this.defaultModel = cheapestModel,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _baseUri = baseUri ?? Uri.parse('https://api.openai.com/v1/');

  static const providerId = 'openai';

  final HttpClientFactory _clientFactory;
  final Uri _baseUri;
  final String defaultModel;

  @override
  String get id => providerId;

  @override
  Future<void> validateKey(String apiKey) async {
    final key = _validatedKey(apiKey);
    final client = _clientFactory();
    try {
      final request = http.Request('GET', _baseUri.resolve('models'))
        ..headers.addAll(_headers(key));
      final response = await client.send(request);
      final body = await response.stream.bytesToString();
      if (response.statusCode != HttpStatus.ok) {
        throw _failureForResponse(response, body);
      }
      final json = _jsonMap(body);
      final models = (json['data'] as List<Object?>? ?? const [])
          .whereType<Map>()
          .map((model) => model['id'])
          .whereType<String>();
      if (!models.contains(defaultModel)) {
        throw AiProviderFailure(
          message: 'The configured OpenAI model is not available for this key.',
        );
      }
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw _failureForException(error);
    } finally {
      client.close();
    }
  }

  @override
  Future<AiCompletion> complete({
    required String apiKey,
    required AiProviderRequest request,
  }) async {
    final key = _validatedKey(apiKey);
    final client = _clientFactory();
    try {
      final httpRequest = http.Request('POST', _baseUri.resolve('responses'))
        ..headers.addAll(_headers(key, json: true))
        ..body = jsonEncode(_requestBody(request, stream: false));
      final response = await client.send(httpRequest);
      final body = await response.stream.bytesToString();
      if (response.statusCode != HttpStatus.ok) {
        throw _failureForResponse(response, body);
      }
      final responseJson = _jsonMap(body);
      final text = _responseText(responseJson);
      if (text.isEmpty || responseJson['status'] != 'completed') {
        throw const AiProviderFailure();
      }
      return AiCompletion(
        text: text,
        providerId: id,
        model: responseJson['model'] as String? ?? request.model,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw _failureForException(error);
    } finally {
      client.close();
    }
  }

  @override
  AiStreamOperation stream({
    required String apiKey,
    required AiProviderRequest request,
  }) {
    final controller = StreamController<AiStreamEvent>();
    final abort = Completer<void>();
    final operation = _OpenAiStreamOperation(
      events: controller.stream,
      cancelRequest: () async {
        if (!abort.isCompleted) abort.complete();
      },
    );
    unawaited(
      _runStream(
        apiKey: apiKey,
        request: request,
        controller: controller,
        abort: abort,
      ),
    );
    return operation;
  }

  Future<void> _runStream({
    required String apiKey,
    required AiProviderRequest request,
    required StreamController<AiStreamEvent> controller,
    required Completer<void> abort,
  }) async {
    http.Client? client;
    var terminalEventSent = false;
    final text = StringBuffer();
    try {
      final key = _validatedKey(apiKey);
      client = _clientFactory();
      final httpRequest =
          http.AbortableRequest(
              'POST',
              _baseUri.resolve('responses'),
              abortTrigger: abort.future,
            )
            ..headers.addAll(_headers(key, json: true))
            ..body = jsonEncode(_requestBody(request, stream: true));
      final response = await client.send(httpRequest);
      if (response.statusCode != HttpStatus.ok) {
        final body = await response.stream.bytesToString();
        throw _failureForResponse(response, body);
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trimLeft();
        if (data.isEmpty || data == '[DONE]') continue;
        final event = _jsonMap(data);
        switch (event['type']) {
          case 'response.output_text.delta':
            final delta = event['delta'] as String? ?? '';
            if (delta.isEmpty) continue;
            text.write(delta);
            controller.add(AiTextDelta(delta));
          case 'response.completed':
            final responseJson = _nestedMap(event['response']);
            final completedText = text.isNotEmpty
                ? text.toString()
                : _responseText(responseJson);
            if (completedText.isEmpty) throw const AiProviderFailure();
            controller.add(
              AiStreamCompleted(
                AiCompletion(
                  text: completedText,
                  providerId: id,
                  model: responseJson['model'] as String? ?? request.model,
                ),
              ),
            );
            terminalEventSent = true;
          case 'response.failed' || 'response.incomplete' || 'error':
            throw _failureForEvent(event);
        }
        if (terminalEventSent) break;
      }
      if (!terminalEventSent) throw const AiProviderFailure();
    } on http.RequestAbortedException {
      if (!terminalEventSent) {
        controller.add(const AiStreamCancelled());
        terminalEventSent = true;
      }
    } on AppFailure catch (failure) {
      if (!terminalEventSent) {
        controller.add(AiStreamFailed(failure));
        terminalEventSent = true;
      }
    } catch (error) {
      if (!terminalEventSent) {
        controller.add(AiStreamFailed(_failureForException(error)));
        terminalEventSent = true;
      }
    } finally {
      client?.close();
      await controller.close();
    }
  }

  static Map<String, String> _headers(String apiKey, {bool json = false}) => {
    HttpHeaders.authorizationHeader: 'Bearer $apiKey',
    HttpHeaders.acceptHeader: json
        ? 'text/event-stream, application/json'
        : 'application/json',
    if (json) HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
  };

  static AiJsonMap _requestBody(
    AiProviderRequest request, {
    required bool stream,
  }) => {
    'model': request.model,
    'instructions': request.instructions,
    'input': request.input,
    'store': false,
    'stream': stream,
    'max_output_tokens': ?request.maxOutputTokens,
    if (request.responseFormat case AiJsonResponseFormat format)
      'text': {
        'format': {
          'type': 'json_schema',
          'json_schema': {
            'name': format.name,
            'strict': true,
            'schema': format.schema,
          },
        },
      },
  };

  static String _validatedKey(String apiKey) {
    final key = apiKey.trim();
    if (key.isEmpty) throw const InvalidApiKeyFailure();
    return key;
  }

  static String _responseText(AiJsonMap response) {
    final direct = response['output_text'];
    if (direct is String && direct.isNotEmpty) return direct;
    final parts = <String>[];
    for (final output in response['output'] as List<Object?>? ?? const []) {
      if (output is! Map) continue;
      for (final content in output['content'] as List<Object?>? ?? const []) {
        if (content is! Map || content['type'] != 'output_text') continue;
        final text = content['text'];
        if (text is String) parts.add(text);
      }
    }
    return parts.join();
  }

  static AppFailure _failureForResponse(
    http.StreamedResponse response,
    String body,
  ) {
    print('OpenAiProvider request failed: ${response.statusCode} - $body');
    final error = _errorMap(body);
    final code = error['code'] as String?;
    if (response.statusCode == HttpStatus.unauthorized) {
      return const InvalidApiKeyFailure();
    }
    if (response.statusCode == HttpStatus.tooManyRequests) {
      if (code == 'insufficient_quota') return const AiQuotaFailure();
      return AiRateLimitFailure(
        retryAfter: _retryAfter(response.headers['retry-after']),
      );
    }
    if (response.statusCode == HttpStatus.requestTimeout) {
      return const NetworkFailure();
    }
    return const AiProviderFailure();
  }

  static AppFailure _failureForEvent(AiJsonMap event) {
    print('OpenAiProvider stream event failure: $event');
    final error = _nestedMap(event['error']);
    final code = error['code'] as String?;
    return switch (code) {
      'invalid_api_key' ||
      'invalid_authentication' => const InvalidApiKeyFailure(),
      'rate_limit_exceeded' => const AiRateLimitFailure(),
      'insufficient_quota' => const AiQuotaFailure(),
      _ => const AiProviderFailure(),
    };
  }

  static AppFailure _failureForException(Object error) {
    print('OpenAiProvider exception: $error');
    return switch (error) {
      AppFailure() => error,
      SocketException() ||
      TimeoutException() ||
      http.ClientException() => const NetworkFailure(),
      _ => const AiProviderFailure(),
    };
  }

  static AiJsonMap _errorMap(String body) {
    try {
      return _nestedMap(_jsonMap(body)['error']);
    } catch (_) {
      return const {};
    }
  }

  static AiJsonMap _jsonMap(String source) =>
      (jsonDecode(source) as Map).cast<String, Object?>();

  static AiJsonMap _nestedMap(Object? value) =>
      value is Map ? value.cast<String, Object?>() : const {};

  static Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value);
    if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
    try {
      final duration = HttpDate.parse(value).difference(DateTime.now().toUtc());
      return duration.isNegative ? Duration.zero : duration;
    } catch (_) {
      return null;
    }
  }
}

final class _OpenAiStreamOperation implements AiStreamOperation {
  const _OpenAiStreamOperation({
    required this.events,
    required this.cancelRequest,
  });

  @override
  final Stream<AiStreamEvent> events;
  final Future<void> Function() cancelRequest;

  @override
  Future<void> cancel() => cancelRequest();
}
