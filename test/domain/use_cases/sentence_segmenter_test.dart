import 'package:flow_reading/domain/use_cases/sentence_segmenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('segments English punctuation and closing quotation marks', () {
    final sentences = SentenceSegmenter.segment(
      blockId: 'block_id',
      text: 'She asked, “Ready?” Yes! I am.',
    );

    expect(sentences.map((sentence) => sentence.text), [
      'She asked, “Ready?” ',
      'Yes! ',
      'I am.',
    ]);
  });

  test('segments common Vietnamese punctuation', () {
    final sentences = SentenceSegmenter.segment(
      blockId: 'block_id',
      text: 'Xin chào! Bạn khỏe không? Tôi khỏe.',
    );

    expect(sentences.map((sentence) => sentence.text), [
      'Xin chào! ',
      'Bạn khỏe không? ',
      'Tôi khỏe.',
    ]);
  });

  test('does not split common abbreviations, initials, or decimals', () {
    final sentences = SentenceSegmenter.segment(
      blockId: 'block_id',
      text: 'Dr. A. Smith lives in TP. Hồ Chí Minh. Value is 3.14.',
    );

    expect(sentences, hasLength(2));
    expect(sentences.first.text, 'Dr. A. Smith lives in TP. Hồ Chí Minh. ');
    expect(sentences.last.text, 'Value is 3.14.');
  });

  test('preserves exact source text, offsets, order, and stable IDs', () {
    const text = '  First sentence.  Second sentence without punctuation';
    final first = SentenceSegmenter.segment(blockId: 'block_id', text: text);
    final second = SentenceSegmenter.segment(blockId: 'block_id', text: text);

    expect(first.map((sentence) => sentence.text).join(), text);
    expect(
      first.map((sentence) => sentence.id),
      second.map((sentence) => sentence.id),
    );
    expect(first.map((sentence) => sentence.order), [0, 1]);
    expect(first.first.startOffset, 0);
    expect(first.last.endOffset, text.length);
    for (final sentence in first) {
      expect(
        text.substring(sentence.startOffset, sentence.endOffset),
        sentence.text,
      );
    }
  });
}
