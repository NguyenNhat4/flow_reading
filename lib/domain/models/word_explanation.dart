import 'package:flow_reading/domain/models/ai_provider_models.dart';

/// Structured contextual explanation for one selected canonical word.
final class WordExplanation {
  WordExplanation({
    required this.description,
    required this.contextualMeaning,
    required List<String> examples,
  }) : examples = List.unmodifiable(examples) {
    if (examples.length < 2) {
      throw const FormatException(
        'A word explanation requires at least two examples',
      );
    }
  }

  final String description;
  final String contextualMeaning;
  final List<String> examples;

  AiJsonMap toJson() => {
    'description': description,
    'contextualMeaning': contextualMeaning,
    'examples': examples,
  };

  factory WordExplanation.fromJson(AiJsonMap json) {
    final sourceExamples = json['examples'];
    if (sourceExamples is! List<Object?> ||
        sourceExamples.any(
          (example) => example is! String || example.trim().isEmpty,
        )) {
      throw const FormatException('Invalid word explanation examples');
    }
    final examples = sourceExamples.cast<String>();
    return WordExplanation(
      description: _requiredString(json, 'description'),
      contextualMeaning: _requiredString(json, 'contextualMeaning'),
      examples: examples,
    );
  }
}

String _requiredString(AiJsonMap json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing word explanation field: $key');
  }
  return value;
}
