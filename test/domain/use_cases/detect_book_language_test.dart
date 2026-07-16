import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/use_cases/detect_book_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects and normalizes a general BCP-47 language', () async {
    final detector = _FakeDetector('zh_hant');
    final service = DetectBookLanguageUseCase(detector);

    final language = await service.detect(
      chapters: [_chapter('這是一段足夠長的繁體中文內容，用來可靠地識別這本書所使用的語言。')],
      declaredLanguage: 'en',
    );

    expect(language, 'zh-Hant');
    expect(detector.sample, isNotEmpty);
  });

  test(
    'caps the canonical text sample at twenty thousand characters',
    () async {
      final detector = _FakeDetector('vi');
      final service = DetectBookLanguageUseCase(detector);

      await service.detect(chapters: [_chapter('a' * 25000)]);

      expect(
        detector.sample.length,
        DetectBookLanguageUseCase.maximumSampleLength,
      );
    },
  );

  test('detector failure falls back to declared metadata language', () async {
    final service = DetectBookLanguageUseCase(_FakeDetector.failure());

    final language = await service.detect(
      chapters: [
        _chapter('A sufficiently long passage for language detection.'),
      ],
      declaredLanguage: 'PT_br',
    );

    expect(language, 'pt-BR');
  });

  test('short or undetermined text does not block import', () async {
    final service = DetectBookLanguageUseCase(_FakeDetector('und'));

    expect(await service.detect(chapters: [_chapter('Short')]), isNull);
  });
}

Chapter _chapter(String text) => Chapter(
  id: 'chapter_id',
  bookId: 'book_id',
  title: 'Chapter',
  order: 0,
  blocks: [
    ParagraphBlock(
      id: 'block_id',
      chapterId: 'chapter_id',
      order: 0,
      spans: [InlineTextSpan(text: text)],
    ),
  ],
);

final class _FakeDetector implements BookLanguageDetector {
  _FakeDetector(this.result) : throwsError = false;
  _FakeDetector.failure() : result = null, throwsError = true;

  final String? result;
  final bool throwsError;
  String sample = '';

  @override
  Future<String?> identify(String text) async {
    sample = text;
    if (throwsError) throw StateError('detector unavailable');
    return result;
  }

  @override
  Future<void> close() async {}
}
