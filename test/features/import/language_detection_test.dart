import 'package:flow_reading/features/import/domain/language_detection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = HeuristicLanguageDetectionService();

  test('detects representative English text offline', () {
    final result = detector.detect(
      'The story is about the river and the people who live in the valley. '
      'It is a book of memory and change.',
    );
    expect(result.languageCode, 'en');
    expect(result.source, contains('heuristic'));
  });

  test('honors a valid metadata hint when text is insufficient', () {
    final result = detector.detect('42', metadataHint: 'pt-BR');
    expect(result.languageCode, 'pt');
    expect(result.source, 'metadata-fallback');
  });
}
