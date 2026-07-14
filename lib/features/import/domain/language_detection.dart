class LanguageDetection {
  const LanguageDetection({
    required this.languageCode,
    required this.confidence,
    required this.source,
  });

  final String languageCode;
  final double confidence;
  final String source;
}

abstract interface class LanguageDetectionService {
  LanguageDetection detect(String representativeText, {String? metadataHint});
}

/// A small, deterministic, offline heuristic. It is deliberately behind an
/// interface so a stronger on-device detector can replace it without changing
/// the EPUB importer.
class HeuristicLanguageDetectionService implements LanguageDetectionService {
  const HeuristicLanguageDetectionService();

  @override
  LanguageDetection detect(String text, {String? metadataHint}) {
    final sample = text.length > 30000 ? text.substring(0, 30000) : text;
    final scriptScores = <String, int>{
      'ar': _count(sample, RegExp(r'[\u0600-\u06ff]')),
      'he': _count(sample, RegExp(r'[\u0590-\u05ff]')),
      'hi': _count(sample, RegExp(r'[\u0900-\u097f]')),
      'th': _count(sample, RegExp(r'[\u0e00-\u0e7f]')),
      'ru': _count(sample, RegExp(r'[\u0400-\u04ff]')),
      'ko': _count(sample, RegExp(r'[\uac00-\ud7af]')),
      'ja': _count(sample, RegExp(r'[\u3040-\u30ff]')),
      'zh': _count(sample, RegExp(r'[\u3400-\u9fff]')),
    };
    final strongest = scriptScores.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    final letters = _count(sample, RegExp(r'[^\W\d_]', unicode: true));
    if (strongest.value >= 8 &&
        strongest.value / (letters == 0 ? 1 : letters) > .12) {
      return LanguageDetection(
        languageCode: strongest.key,
        confidence: (.72 + strongest.value / (letters == 0 ? 1 : letters))
            .clamp(.72, .99),
        source: 'offline-script-heuristic',
      );
    }

    final lower = ' ${sample.toLowerCase()} ';
    final latinScores = <String, int>{
      'vi':
          _words(lower, const [' và ', ' của ', ' không ', ' một ', ' được ']) +
          _count(
                lower,
                RegExp(
                  r'[ăâđêôơưáàảãạấầẩẫậắằẳẵặéèẻẽẹíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ]',
                ),
              ) *
              2,
      'en': _words(lower, const [
        ' the ',
        ' and ',
        ' of ',
        ' to ',
        ' in ',
        ' that ',
        ' is ',
      ]),
      'fr': _words(lower, const [
        ' le ',
        ' la ',
        ' les ',
        ' de ',
        ' et ',
        ' une ',
        ' des ',
      ]),
      'es': _words(lower, const [
        ' el ',
        ' la ',
        ' los ',
        ' de ',
        ' que ',
        ' y ',
        ' una ',
      ]),
      'de': _words(lower, const [
        ' der ',
        ' die ',
        ' das ',
        ' und ',
        ' ist ',
        ' nicht ',
      ]),
      'it': _words(lower, const [
        ' il ',
        ' la ',
        ' di ',
        ' che ',
        ' e ',
        ' una ',
      ]),
    };
    final best = latinScores.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    final normalizedHint = metadataHint
        ?.trim()
        .toLowerCase()
        .split(RegExp('[-_]'))
        .first;
    if (best.value >= 3) {
      final agrees = normalizedHint == best.key;
      return LanguageDetection(
        languageCode: best.key,
        confidence: (0.58 + best.value * .025 + (agrees ? .12 : 0)).clamp(
          .58,
          .96,
        ),
        source: agrees
            ? 'offline-heuristic+metadata'
            : 'offline-word-heuristic',
      );
    }
    if (normalizedHint != null &&
        RegExp(r'^[a-z]{2,3}$').hasMatch(normalizedHint)) {
      return LanguageDetection(
        languageCode: normalizedHint,
        confidence: .55,
        source: 'metadata-fallback',
      );
    }
    return const LanguageDetection(
      languageCode: 'und',
      confidence: .2,
      source: 'insufficient-text',
    );
  }

  static int _count(String value, RegExp pattern) =>
      pattern.allMatches(value).length;

  static int _words(String value, List<String> words) =>
      words.fold(0, (total, word) => total + word.allMatches(value).length);
}
