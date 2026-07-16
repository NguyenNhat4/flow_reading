import 'package:flow_reading/domain/models/ai_provider_models.dart';

/// Structured contextual explanation for one selected canonical word.
final class WordExplanation {
  WordExplanation({
    required this.contextualMeaning,
    required this.partOfSpeech,
    required this.reasonUsed,
    required this.simplerParaphrase,
    required List<String> examples,
    this.ambiguityWarning,
  }) : examples = List.unmodifiable(examples) {
    if (examples.length < 2) {
      throw const FormatException(
        'A word explanation requires at least two examples',
      );
    }
  }

  final String contextualMeaning;
  final String partOfSpeech;
  final String reasonUsed;
  final String simplerParaphrase;
  final List<String> examples;
  final String? ambiguityWarning;

  AiJsonMap toJson() => {
    'contextualMeaning': contextualMeaning,
    'partOfSpeech': partOfSpeech,
    'reasonUsed': reasonUsed,
    'simplerParaphrase': simplerParaphrase,
    'examples': examples,
    'ambiguityWarning': ambiguityWarning,
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
      contextualMeaning: _requiredString(json, 'contextualMeaning'),
      partOfSpeech: _requiredString(json, 'partOfSpeech'),
      reasonUsed: _requiredString(json, 'reasonUsed'),
      simplerParaphrase: _requiredString(json, 'simplerParaphrase'),
      examples: examples,
      ambiguityWarning: switch (json['ambiguityWarning']) {
        null => null,
        final String value when value.trim().isNotEmpty => value,
        final String _ => null,
        _ => throw const FormatException('Invalid ambiguity warning'),
      },
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
