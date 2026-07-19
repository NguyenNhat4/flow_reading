import 'dart:convert';

import 'package:flow_reading/domain/models/ai_context.dart';
import 'package:flow_reading/domain/models/ai_prompt.dart';
import 'package:flow_reading/domain/models/ai_provider_models.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/services/sha256.dart';

/// One successful AI artifact that can be reused without network access.
final class AiCacheEntry {
  factory AiCacheEntry.create({
    required String bookId,
    required AiRequestType requestType,
    required TextAnchor? sourceRange,
    required String contentHash,
    required String contextFingerprint,
    required String promptId,
    required int promptVersion,
    required AiJsonMap response,
    required String provider,
    required String model,
    required DateTime createdAt,
  }) {
    final id = computeId(
      bookId: bookId,
      requestType: requestType,
      sourceRange: sourceRange,
      contentHash: contentHash,
      contextFingerprint: contextFingerprint,
      promptId: promptId,
      promptVersion: promptVersion,
      provider: provider,
      model: model,
    );
    return AiCacheEntry._(
      id: id,
      bookId: bookId,
      requestType: requestType,
      sourceRange: sourceRange,
      contentHash: contentHash,
      contextFingerprint: contextFingerprint,
      promptId: promptId,
      promptVersion: promptVersion,
      response: response,
      provider: provider,
      model: model,
      createdAt: createdAt,
    );
  }

  AiCacheEntry._({
    required this.id,
    required this.bookId,
    required this.requestType,
    required this.sourceRange,
    required this.contentHash,
    required this.contextFingerprint,
    required this.promptId,
    required this.promptVersion,
    required AiJsonMap response,
    required this.provider,
    required this.model,
    required this.createdAt,
  }) : response = Map.unmodifiable(response) {
    if (requestType == AiRequestType.chat) {
      throw ArgumentError('Chat responses are not cacheable artifacts');
    }
    if (promptVersion <= 0) {
      throw ArgumentError.value(
        promptVersion,
        'promptVersion',
        'Must be positive',
      );
    }
  }

  final String id;
  final String bookId;
  final AiRequestType requestType;
  final TextAnchor? sourceRange;
  final String contentHash;
  final String contextFingerprint;
  final String promptId;
  final int promptVersion;
  final AiJsonMap response;
  final String provider;
  final String model;
  final DateTime createdAt;

  AiJsonMap toJson() => {
    'id': id,
    'bookId': bookId,
    'requestType': requestType.name,
    'sourceRange': sourceRange?.toJson(),
    'contentHash': contentHash,
    'contextFingerprint': contextFingerprint,
    'promptId': promptId,
    'promptVersion': promptVersion,
    'response': response,
    'provider': provider,
    'model': model,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory AiCacheEntry.fromJson(AiJsonMap json) {
    final requestType = AiRequestType.values.byName(
      json['requestType'] as String,
    );
    final sourceRangeJson = json['sourceRange'];
    final entry = AiCacheEntry.create(
      bookId: json['bookId'] as String,
      requestType: requestType,
      sourceRange: sourceRangeJson == null
          ? null
          : TextAnchor.fromJson(
              (sourceRangeJson as Map).cast<String, Object?>(),
            ),
      contentHash: json['contentHash'] as String,
      contextFingerprint: json['contextFingerprint'] as String,
      promptId: json['promptId'] as String,
      promptVersion: json['promptVersion'] as int,
      response: (json['response'] as Map).cast<String, Object?>(),
      provider: json['provider'] as String,
      model: json['model'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    );
    if (json['id'] != entry.id) {
      throw const FormatException('AI cache ID does not match its inputs');
    }
    return entry;
  }

  /// Computes the deterministic compatibility key for one artifact request.
  static String computeId({
    required String bookId,
    required AiRequestType requestType,
    required TextAnchor? sourceRange,
    required String contentHash,
    required String contextFingerprint,
    required String promptId,
    required int promptVersion,
    required String provider,
    required String model,
  }) =>
      'ai_${sha256Hex(utf8.encode(jsonEncode([bookId, requestType.name, sourceRange?.toJson(), contentHash, contextFingerprint, promptId, promptVersion, provider, model])))}';
}

/// Creates hashes used to invalidate incompatible cached AI artifacts.
abstract final class AiCacheFingerprints {
  static String content(String sourceText) =>
      sha256Hex(utf8.encode(sourceText));

  static String context(AiContextPackage context) => sha256Hex(
    utf8.encode(
      jsonEncode({
        'chapterTitle': context.chapterTitle,
        'currentPosition': context.currentPosition.anchor.toJson(),
        'passages': [
          for (final passage in context.passages)
            {
              'roles': passage.roles.map((role) => role.name).toList()..sort(),
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
      }),
    ),
  );
}
