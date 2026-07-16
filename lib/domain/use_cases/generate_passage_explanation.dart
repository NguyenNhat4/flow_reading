import 'dart:async';
import 'dart:convert';

import 'package:flow_reading/domain/models/ai_cache_entry.dart';
import 'package:flow_reading/domain/models/ai_prompt.dart';
import 'package:flow_reading/domain/models/ai_provider_models.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/passage_explanation.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/ai_artifact_repository.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:flow_reading/domain/use_cases/ai_prompt_registry.dart';
import 'package:flow_reading/domain/use_cases/build_ai_context.dart';

sealed class PassageExplanationEvent {
  const PassageExplanationEvent();
}

final class PassageExplanationCompleted extends PassageExplanationEvent {
  const PassageExplanationCompleted({
    required this.explanation,
    required this.fromCache,
  });

  final PassageExplanation explanation;
  final bool fromCache;
}

final class PassageExplanationFailed extends PassageExplanationEvent {
  const PassageExplanationFailed(this.error);

  final Object error;
}

final class PassageExplanationCancelled extends PassageExplanationEvent {
  const PassageExplanationCancelled();
}

/// One cancellable passage-explanation request.
final class PassageExplanationSession {
  const PassageExplanationSession({
    required Stream<PassageExplanationEvent> events,
    required Future<void> Function() cancel,
  }) : this._(events, cancel);

  const PassageExplanationSession._(this.events, this._cancel);

  final Stream<PassageExplanationEvent> events;
  final Future<void> Function() _cancel;

  Future<void> cancel() => _cancel();
}

/// Starts cache-first, cancellable passage explanations.
final class GeneratePassageExplanationUseCase {
  const GeneratePassageExplanationUseCase({
    required BuildAiContextUseCase contextBuilder,
    required AiArtifactRepository artifactRepository,
    required AiCredentialRepository credentialRepository,
    required AiProvider provider,
    required String model,
  }) : this._(
         contextBuilder,
         artifactRepository,
         credentialRepository,
         provider,
         model,
       );

  const GeneratePassageExplanationUseCase._(
    this._contextBuilder,
    this._artifactRepository,
    this._credentialRepository,
    this._provider,
    this._model,
  );

  final BuildAiContextUseCase _contextBuilder;
  final AiArtifactRepository _artifactRepository;
  final AiCredentialRepository _credentialRepository;
  final AiProvider _provider;
  final String _model;

  Future<PassageExplanationSession> start({
    required List<Chapter> chapters,
    required PassageSelection selection,
    required ReadingLocator currentPosition,
  }) async {
    final context = await _contextBuilder.build(
      chapters: chapters,
      selection: selection.anchor,
      selectedText: selection.textSnapshot,
      currentPosition: currentPosition,
    );
    final template = AiPromptRegistry.templateFor(
      AiRequestType.passageExplanation,
    );
    final contentHash = AiCacheFingerprints.content(selection.textSnapshot);
    final contextFingerprint = AiCacheFingerprints.context(context);
    final cacheId = AiCacheEntry.computeId(
      bookId: selection.anchor.bookId,
      requestType: AiRequestType.passageExplanation,
      sourceRange: selection.anchor,
      contentHash: contentHash,
      contextFingerprint: contextFingerprint,
      promptId: template.id,
      promptVersion: template.version,
      provider: _provider.id,
      model: _model,
    );
    final cached = await _artifactRepository.read(cacheId);
    if (cached != null) {
      return PassageExplanationSession(
        events: Stream.value(
          PassageExplanationCompleted(
            explanation: PassageExplanation.fromJson(cached.response),
            fromCache: true,
          ),
        ),
        cancel: () async {},
      );
    }

    final apiKey = await _credentialRepository.read(_provider.id);
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiNotConfiguredFailure();
    }
    final providerOperation = _provider.stream(
      apiKey: apiKey,
      request: template.buildRequest(model: _model, context: context),
    );
    final controller = StreamController<PassageExplanationEvent>();
    unawaited(
      _forward(
        providerOperation: providerOperation,
        controller: controller,
        selection: selection,
        contentHash: contentHash,
        contextFingerprint: contextFingerprint,
        templateId: template.id,
        templateVersion: template.version,
      ),
    );
    return PassageExplanationSession(
      events: controller.stream,
      cancel: providerOperation.cancel,
    );
  }

  Future<void> _forward({
    required AiStreamOperation providerOperation,
    required StreamController<PassageExplanationEvent> controller,
    required PassageSelection selection,
    required String contentHash,
    required String contextFingerprint,
    required String templateId,
    required int templateVersion,
  }) async {
    try {
      await for (final event in providerOperation.events) {
        switch (event) {
          case AiTextDelta():
            break;
          case AiStreamCompleted(:final completion):
            try {
              final explanation = _decode(completion.text);
              await _artifactRepository.save(
                AiCacheEntry.create(
                  bookId: selection.anchor.bookId,
                  requestType: AiRequestType.passageExplanation,
                  sourceRange: selection.anchor,
                  contentHash: contentHash,
                  contextFingerprint: contextFingerprint,
                  promptId: templateId,
                  promptVersion: templateVersion,
                  response: explanation.toJson(),
                  provider: _provider.id,
                  model: _model,
                  createdAt: DateTime.now().toUtc(),
                ),
              );
              controller.add(
                PassageExplanationCompleted(
                  explanation: explanation,
                  fromCache: false,
                ),
              );
            } catch (error) {
              controller.add(PassageExplanationFailed(error));
            }
          case AiStreamFailed(:final failure):
            controller.add(PassageExplanationFailed(failure));
          case AiStreamCancelled():
            controller.add(const PassageExplanationCancelled());
        }
      }
    } catch (error) {
      controller.add(PassageExplanationFailed(error));
    } finally {
      await controller.close();
    }
  }

  static PassageExplanation _decode(String source) {
    try {
      return PassageExplanation.fromJson(
        (jsonDecode(source) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid passage explanation response');
    }
  }
}
