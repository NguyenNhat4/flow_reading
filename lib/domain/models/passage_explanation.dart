import 'package:flow_reading/domain/models/ai_provider_models.dart';

/// Structured explanation of one selected canonical passage.
final class PassageExplanation {
  PassageExplanation({
    required this.explanation,
    required List<String> explicitFacts,
    required List<String> interpretations,
    this.ambiguityWarning,
  }) : explicitFacts = List.unmodifiable(explicitFacts),
       interpretations = List.unmodifiable(interpretations);

  final String explanation;
  final List<String> explicitFacts;
  final List<String> interpretations;
  final String? ambiguityWarning;

  AiJsonMap toJson() => {
    'explanation': explanation,
    'explicitFacts': explicitFacts,
    'interpretations': interpretations,
    'ambiguityWarning': ambiguityWarning,
  };

  factory PassageExplanation.fromJson(AiJsonMap json) => PassageExplanation(
    explanation: _requiredString(json, 'explanation'),
    explicitFacts: _stringList(json, 'explicitFacts'),
    interpretations: _stringList(json, 'interpretations'),
    ambiguityWarning: switch (json['ambiguityWarning']) {
      null => null,
      final String value when value.trim().isNotEmpty => value,
      final String _ => null,
      _ => throw const FormatException('Invalid ambiguity warning'),
    },
  );
}

String _requiredString(AiJsonMap json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing passage explanation field: $key');
  }
  return value;
}

List<String> _stringList(AiJsonMap json, String key) {
  final value = json[key];
  if (value is! List<Object?> ||
      value.any((item) => item is! String || item.trim().isEmpty)) {
    throw FormatException('Invalid passage explanation field: $key');
  }
  return value.cast<String>();
}
