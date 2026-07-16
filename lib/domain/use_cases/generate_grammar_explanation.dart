import 'dart:convert';

import 'package:flow_reading/domain/models/ai_cache_entry.dart';
import 'package:flow_reading/domain/models/ai_prompt.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/grammar_explanation.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/ai_artifact_repository.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:flow_reading/domain/use_cases/ai_prompt_registry.dart';
import 'package:flow_reading/domain/use_cases/build_ai_context.dart';

final class GrammarExplanationResult {
  const GrammarExplanationResult({
    required this.explanation,
    required this.fromCache,
  });

  final GrammarExplanation explanation;
  final bool fromCache;
}

/// Generates or restores grammar help for one selected passage.
final class GenerateGrammarExplanationUseCase {
  const GenerateGrammarExplanationUseCase({
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

  const GenerateGrammarExplanationUseCase._(
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

  Future<GrammarExplanationResult> call({
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
      AiRequestType.grammarExplanation,
    );
    final contentHash = AiCacheFingerprints.content(selection.textSnapshot);
    final contextFingerprint = AiCacheFingerprints.context(context);
    final cacheId = AiCacheEntry.computeId(
      bookId: selection.anchor.bookId,
      requestType: AiRequestType.grammarExplanation,
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
      return GrammarExplanationResult(
        explanation: GrammarExplanation.fromJson(cached.response),
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
    final explanation = _decode(completion.text);
    await _artifactRepository.save(
      AiCacheEntry.create(
        bookId: selection.anchor.bookId,
        requestType: AiRequestType.grammarExplanation,
        sourceRange: selection.anchor,
        contentHash: contentHash,
        contextFingerprint: contextFingerprint,
        promptId: template.id,
        promptVersion: template.version,
        response: explanation.toJson(),
        provider: _provider.id,
        model: _model,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return GrammarExplanationResult(explanation: explanation, fromCache: false);
  }

  static GrammarExplanation _decode(String source) {
    try {
      return GrammarExplanation.fromJson(
        (jsonDecode(source) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid grammar explanation response');
    }
  }
}
