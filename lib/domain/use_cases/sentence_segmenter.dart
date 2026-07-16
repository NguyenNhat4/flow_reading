import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/content_identifiers.dart';

abstract final class SentenceSegmenter {
  static const _abbreviations = {
    'mr',
    'mrs',
    'ms',
    'dr',
    'prof',
    'sr',
    'jr',
    'st',
    'vs',
    'e.g',
    'i.e',
    'no',
    'vol',
    'chap',
    'tp',
    'ts',
    'pgs',
    'ths',
  };
  static const _closingMarks = {'"', "'", '’', '”', ')', ']', '}'};

  static List<BookSentence> segment({
    required String blockId,
    required String text,
  }) {
    if (text.isEmpty) return const [];
    final ranges = <(int, int)>[];
    var start = 0;
    var index = 0;
    while (index < text.length) {
      final character = text[index];
      if (character != '.' && character != '!' && character != '?') {
        index++;
        continue;
      }

      if (character == '.' && _isProtectedPeriod(text, index)) {
        index++;
        continue;
      }

      var end = index + 1;
      while (end < text.length && text[end] == character) {
        end++;
      }
      while (end < text.length && _closingMarks.contains(text[end])) {
        end++;
      }
      while (end < text.length && _isWhitespace(text[end])) {
        end++;
      }
      ranges.add((start, end));
      start = end;
      index = end;
    }
    if (start < text.length) ranges.add((start, text.length));
    if (ranges.isEmpty) ranges.add((0, text.length));

    return List.generate(ranges.length, (order) {
      final (startOffset, endOffset) = ranges[order];
      final sentenceText = text.substring(startOffset, endOffset);
      return BookSentence(
        id: ContentIdentifiers.sentence(
          blockId: blockId,
          startOffset: startOffset,
          endOffset: endOffset,
          text: sentenceText,
        ),
        blockId: blockId,
        order: order,
        startOffset: startOffset,
        endOffset: endOffset,
        text: sentenceText,
      );
    });
  }

  static bool _isProtectedPeriod(String text, int index) {
    if (index > 0 &&
        index + 1 < text.length &&
        _isDigit(text[index - 1]) &&
        _isDigit(text[index + 1])) {
      return true;
    }

    if (index + 1 < text.length && text[index + 1] == '.') {
      return false;
    }

    final tokenStart = _tokenStart(text, index);
    final token = text.substring(tokenStart, index).toLowerCase();
    if (_abbreviations.contains(token)) return true;

    if (token.length == 1 && _isLetter(token)) {
      return true;
    }

    if (index >= 2 && _isLetter(text[index - 1]) && text[index - 2] == '.') {
      return true;
    }
    return false;
  }

  static int _tokenStart(String text, int end) {
    var start = end;
    while (start > 0) {
      final character = text[start - 1];
      if (!_isLetter(character) && character != '.') break;
      start--;
    }
    return start;
  }

  static bool _isWhitespace(String character) => character.trim().isEmpty;

  static bool _isDigit(String character) => RegExp(r'^\d$').hasMatch(character);

  static bool _isLetter(String character) =>
      RegExp(r'^\p{L}$', unicode: true).hasMatch(character);
}
