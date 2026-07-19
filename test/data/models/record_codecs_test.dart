import 'package:flow_reading/data/models/book_record_codec.dart';
import 'package:flow_reading/data/models/reader_state_record_codec.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('book codec preserves the existing canonical JSON shape', () {
    const chapter = Chapter(
      id: 'chapter',
      bookId: 'book',
      title: 'Chapter',
      order: 0,
      blocks: [
        ParagraphBlock(
          id: 'block',
          chapterId: 'chapter',
          order: 0,
          spans: [InlineTextSpan(text: 'Hello')],
        ),
      ],
    );

    final encoded = BookRecordCodec.encodeChapter(chapter);
    expect(encoded['id'], 'chapter');
    expect(encoded['blocks'], hasLength(1));
    final decoded = BookRecordCodec.decodeChapter(encoded);
    expect(decoded.id, chapter.id);
    expect((decoded.blocks.single as ParagraphBlock).text, 'Hello');
  });

  test('reader codec preserves stable locator and settings payloads', () {
    final locator = ReadingLocator(
      anchor: TextAnchor(
        bookId: 'book',
        chapterId: 'chapter',
        blockId: 'block',
        startOffset: 4,
        endOffset: 4,
      ),
    );

    final locatorJson = ReaderStateRecordCodec.encodeLocator(locator);
    expect(locatorJson, locator.toJson());
    expect(
      ReaderStateRecordCodec.decodeLocator(locatorJson).anchor.id,
      locator.anchor.id,
    );

    final settingsJson = ReaderStateRecordCodec.encodeSettings(
      ReaderSettings.defaults,
    );
    expect(
      ReaderStateRecordCodec.decodeSettings(settingsJson),
      ReaderSettings.defaults,
    );
  });
}
