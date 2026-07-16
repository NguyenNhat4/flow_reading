import 'package:flow_reading/domain/models/ai_provider_models.dart';

/// One grammar feature tied to exact evidence in a selected passage.
final class GrammarExplanationPoint {
  const GrammarExplanationPoint({
    required this.feature,
    required this.evidence,
    required this.explanation,
    required this.relevance,
  });

  final String feature;
  final String evidence;
  final String explanation;
  final String relevance;

  AiJsonMap toJson() => {
    'feature': feature,
    'evidence': evidence,
    'explanation': explanation,
    'relevance': relevance,
  };

  factory GrammarExplanationPoint.fromJson(AiJsonMap json) =>
      GrammarExplanationPoint(
        feature: _requiredString(json, 'feature'),
        evidence: _requiredString(json, 'evidence'),
        explanation: _requiredString(json, 'explanation'),
        relevance: _requiredString(json, 'relevance'),
      );
}

/// Structured grammar help limited to understanding one selected passage.
final class GrammarExplanation {
  GrammarExplanation({
    required List<GrammarExplanationPoint> points,
    required List<String> interpretations,
  }) : points = List.unmodifiable(points),
       interpretations = List.unmodifiable(interpretations) {
    if (points.isEmpty) {
      throw const FormatException(
        'A grammar explanation requires at least one relevant point',
      );
    }
  }

  final List<GrammarExplanationPoint> points;
  final List<String> interpretations;

  AiJsonMap toJson() => {
    'points': [for (final point in points) point.toJson()],
    'interpretations': interpretations,
  };

  factory GrammarExplanation.fromJson(AiJsonMap json) {
    final sourcePoints = json['points'];
    if (sourcePoints is! List<Object?> ||
        sourcePoints.any((point) => point is! Map)) {
      throw const FormatException('Invalid grammar explanation points');
    }
    final sourceInterpretations = json['interpretations'];
    if (sourceInterpretations is! List<Object?> ||
        sourceInterpretations.any(
          (item) => item is! String || item.trim().isEmpty,
        )) {
      throw const FormatException('Invalid grammar interpretations');
    }
    return GrammarExplanation(
      points: [
        for (final point in sourcePoints)
          GrammarExplanationPoint.fromJson(
            (point as Map).cast<String, Object?>(),
          ),
      ],
      interpretations: sourceInterpretations.cast<String>(),
    );
  }
}

String _requiredString(AiJsonMap json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing grammar explanation field: $key');
  }
  return value;
}
