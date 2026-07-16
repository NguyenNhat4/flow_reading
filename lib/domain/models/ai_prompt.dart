import 'dart:convert';

import 'package:flow_reading/domain/models/ai_context.dart';
import 'package:flow_reading/domain/models/ai_provider_models.dart';

/// Product-level AI operations supported by versioned prompt templates.
enum AiRequestType {
  wordExplanation,
  passageExplanation,
  grammarExplanation,
  summary,
  translation,
  chapterOverview,
  chat,
}

/// One versioned product prompt independent of any provider implementation.
final class AiPromptTemplate {
  AiPromptTemplate({
    required this.id,
    required this.version,
    required this.requestType,
    required this.instructions,
    required this.responseFormat,
    required this.maxOutputTokens,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
    if (version <= 0) {
      throw ArgumentError.value(version, 'version', 'Must be positive');
    }
  }

  final String id;
  final int version;
  final AiRequestType requestType;
  final String instructions;
  final AiResponseFormat responseFormat;
  final int maxOutputTokens;

  /// Renders canonical context and operation parameters into a provider request.
  AiProviderRequest buildRequest({
    required String model,
    required AiContextPackage context,
    String? targetLanguage,
    String? question,
  }) {
    final normalizedLanguage = targetLanguage?.trim();
    if (requestType == AiRequestType.translation &&
        (normalizedLanguage == null || normalizedLanguage.isEmpty)) {
      throw ArgumentError.value(
        targetLanguage,
        'targetLanguage',
        'Translation requires a target language',
      );
    }
    final normalizedQuestion = question?.trim();
    if (requestType == AiRequestType.chat &&
        (normalizedQuestion == null || normalizedQuestion.isEmpty)) {
      throw ArgumentError.value(
        question,
        'question',
        'Chat requires a question',
      );
    }
    return AiProviderRequest(
      model: model,
      instructions: instructions,
      input: jsonEncode({
        'promptId': id,
        'promptVersion': version,
        'requestType': requestType.name,
        'targetLanguage': ?normalizedLanguage,
        'question': ?normalizedQuestion,
        'context': _contextJson(context),
      }),
      responseFormat: responseFormat,
      maxOutputTokens: maxOutputTokens,
    );
  }
}

Map<String, Object?> _contextJson(AiContextPackage context) => {
  'chapterTitle': context.chapterTitle,
  'currentPosition': context.currentPosition.anchor.toJson(),
  'passages': [
    for (final passage in context.passages)
      {
        'roles': passage.roles.map((role) => role.name).toList(),
        'anchor': passage.anchor.toJson(),
        'text': passage.text,
      },
  ],
  'recentMessages': [
    for (final message in context.recentMessages)
      {
        'role': message.role.name,
        'text': message.text,
        'referencedRanges': [
          for (final range in message.referencedRanges) range.toJson(),
        ],
      },
  ],
};
