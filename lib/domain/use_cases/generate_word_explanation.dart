import 'dart:convert';

import 'package:flow_reading/domain/models/ai_cache_entry.dart';
import 'package:flow_reading/domain/models/ai_prompt.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/models/word_explanation.dart';
import 'package:flow_reading/domain/repositories/ai_artifact_repository.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:flow_reading/domain/use_cases/ai_prompt_registry.dart';
import 'package:flow_reading/domain/use_cases/build_ai_context.dart';

/// A word explanation together with its offline-cache provenance.
final class WordExplanationResult {
  const WordExplanationResult({
    required this.explanation,
    required this.fromCache,
  });

  final WordExplanation explanation;
  final bool fromCache;
}

/// Generates or restores a contextual explanation for one selected word.
final class GenerateWordExplanationUseCase {
  const GenerateWordExplanationUseCase({
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

  const GenerateWordExplanationUseCase._(
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

  Future<WordExplanationResult> call({
    required List<Chapter> chapters,
    required WordSelection selection,
    required ReadingLocator currentPosition,
  }) async {
    final context = await _contextBuilder.build(
      chapters: chapters,
      selection: selection.anchor,
      selectedText: selection.textSnapshot,
      currentPosition: currentPosition,
    );
    final template = AiPromptRegistry.templateFor(
      AiRequestType.wordExplanation,
    );
    final contentHash = AiCacheFingerprints.content(selection.textSnapshot);
    final contextFingerprint = AiCacheFingerprints.context(context);
    final cacheId = AiCacheEntry.computeId(
      bookId: selection.anchor.bookId,
      requestType: AiRequestType.wordExplanation,
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
      return WordExplanationResult(
        explanation: WordExplanation.fromJson(cached.response),
        fromCache: true,
      );
    }

    final apiKey = await _credentialRepository.read(_provider.id);
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiNotConfiguredFailure();
    }
    final completion = await _provider.complete(
      apiKey: apiKey,
      request: template.buildRequest(model: _model, context: context),
    );
    final response = _decodeExplanation(completion.text);
    await _artifactRepository.save(
      AiCacheEntry.create(
        bookId: selection.anchor.bookId,
        requestType: AiRequestType.wordExplanation,
        sourceRange: selection.anchor,
        contentHash: contentHash,
        contextFingerprint: contextFingerprint,
        promptId: template.id,
        promptVersion: template.version,
        response: response.toJson(),
        provider: _provider.id,
        model: _model,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return WordExplanationResult(explanation: response, fromCache: false);
  }

  static WordExplanation _decodeExplanation(String source) {
    try {
      return WordExplanation.fromJson(
        (jsonDecode(source) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid word explanation response');
    }
  }
}
