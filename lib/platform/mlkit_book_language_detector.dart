import 'package:flow_reading/books/book_language_detector.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

final class MlKitBookLanguageDetector implements BookLanguageDetector {
  MlKitBookLanguageDetector({double confidenceThreshold = 0.5})
    : _identifier = LanguageIdentifier(
        confidenceThreshold: confidenceThreshold,
      );

  final LanguageIdentifier _identifier;

  @override
  Future<String?> identify(String text) async {
    final language = await _identifier.identifyLanguage(text);
    return language == 'und' ? null : language;
  }

  @override
  Future<void> close() async => _identifier.close();
}
