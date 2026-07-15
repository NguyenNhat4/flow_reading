import 'package:flow_reading/books/book_models.dart';

abstract interface class BookLanguageDetector {
  Future<String?> identify(String text);

  Future<void> close();
}

final class BookLanguageDetectionService {
  const BookLanguageDetectionService(this.detector);

  static const maximumSampleLength = 20000;
  static const minimumSampleLength = 20;

  final BookLanguageDetector detector;

  Future<String?> detect({
    required List<Chapter> chapters,
    String? declaredLanguage,
  }) async {
    final sample = _sample(chapters);
    if (sample.trim().length >= minimumSampleLength) {
      try {
        final identified = normalize(await detector.identify(sample));
        if (identified != null && identified != 'und') return identified;
      } catch (_) {
        // Detection is optional and must never block local import.
      }
    }
    return normalize(declaredLanguage);
  }

  static String? normalize(String? language) {
    final value = language?.trim().replaceAll('_', '-');
    if (value == null || value.isEmpty) return null;
    final parts = value.split('-');
    final normalized = <String>[parts.first.toLowerCase()];
    for (final part in parts.skip(1)) {
      if (part.length == 2 || part.length == 3 && _isNumeric(part)) {
        normalized.add(part.toUpperCase());
      } else if (part.length == 4) {
        normalized.add(
          '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
        );
      } else {
        normalized.add(part.toLowerCase());
      }
    }
    return normalized.join('-');
  }

  static String _sample(List<Chapter> chapters) {
    final buffer = StringBuffer();
    void add(String value) {
      if (buffer.length >= maximumSampleLength || value.trim().isEmpty) return;
      if (buffer.isNotEmpty) buffer.write('\n');
      final remaining = maximumSampleLength - buffer.length;
      buffer.write(
        value.length <= remaining ? value : value.substring(0, remaining),
      );
    }

    void addListItem(BookListItem item) {
      add(item.text);
      for (final child in item.children) {
        addListItem(child);
      }
    }

    for (final chapter in chapters) {
      for (final block in chapter.blocks) {
        switch (block) {
          case ParagraphBlock():
            add(block.text);
          case HeadingBlock():
            add(block.text);
          case QuoteBlock():
            add(block.text);
          case ListBlock():
            for (final item in block.items) {
              addListItem(item);
            }
          case ImageBlock():
            break;
        }
        if (buffer.length >= maximumSampleLength) return buffer.toString();
      }
    }
    return buffer.toString();
  }

  static bool _isNumeric(String value) => int.tryParse(value) != null;
}
