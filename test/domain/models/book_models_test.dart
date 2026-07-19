import 'dart:convert';

import 'package:flow_reading/data/models/book_record_codec.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes and restores the complete canonical book model', () {
    final book = Book(
      id: 'book-1',
      metadata: const BookMetadata(
        title: 'A Book',
        authors: ['Author'],
        language: 'en',
        coverAssetId: 'asset-cover',
      ),
      originalFile: '/books/book-1.epub',
      chapters: const [
        Chapter(
          id: 'chapter-1',
          bookId: 'book-1',
          title: 'Opening',
          order: 0,
          sourceHref: 'opening.xhtml',
          blocks: [
            HeadingBlock(
              id: 'heading-1',
              chapterId: 'chapter-1',
              order: 0,
              level: 1,
              spans: [InlineTextSpan(text: 'Opening', bold: true)],
            ),
            ParagraphBlock(
              id: 'paragraph-1',
              chapterId: 'chapter-1',
              order: 1,
              spans: [
                InlineTextSpan(text: 'Read '),
                InlineTextSpan(
                  text: 'carefully',
                  italic: true,
                  href: 'notes.xhtml#one',
                ),
                InlineTextSpan(text: '.'),
              ],
              sentences: [
                BookSentence(
                  id: 'sentence-1',
                  blockId: 'paragraph-1',
                  order: 0,
                  startOffset: 0,
                  endOffset: 15,
                  text: 'Read carefully.',
                ),
              ],
            ),
            ImageBlock(
              id: 'image-1',
              chapterId: 'chapter-1',
              order: 2,
              assetId: 'asset-cover',
              altText: 'Cover',
            ),
            ListBlock(
              id: 'list-1',
              chapterId: 'chapter-1',
              order: 3,
              ordered: true,
              items: [
                BookListItem(
                  spans: [InlineTextSpan(text: 'First')],
                  children: [
                    BookListItem(spans: [InlineTextSpan(text: 'Nested')]),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      tableOfContents: const [
        TableOfContentsEntry(
          title: 'Opening',
          reference: ChapterReference(
            chapterId: 'chapter-1',
            blockId: 'heading-1',
          ),
        ),
      ],
      assets: const [
        BookAsset(
          id: 'asset-cover',
          bookId: 'book-1',
          mediaType: 'image/jpeg',
          localPath: '/books/book-1/cover.jpg',
          sourceHref: 'images/cover.jpg',
        ),
      ],
      detectedLanguage: 'en',
      importedAt: DateTime.utc(2026, 7, 15),
    );

    final encoded = jsonEncode(BookRecordCodec.encodeBook(book));
    final restored = BookRecordCodec.decodeBook(
      (jsonDecode(encoded) as Map).cast<String, Object?>(),
    );

    expect(
      BookRecordCodec.encodeBook(restored),
      BookRecordCodec.encodeBook(book),
    );
    expect(restored.chapters.single.blocks, hasLength(4));
    expect(restored.chapters.single.blocks[0], isA<HeadingBlock>());
    expect(restored.chapters.single.blocks[1], isA<ParagraphBlock>());
    expect(restored.chapters.single.blocks[2], isA<ImageBlock>());
    expect(restored.chapters.single.blocks[3], isA<ListBlock>());
  });

  test('preserves chapter, block, and table-of-contents order', () {
    const chapters = [
      Chapter(
        id: 'second-in-spine',
        bookId: 'book',
        title: 'Second',
        order: 1,
        blocks: [],
      ),
      Chapter(
        id: 'first-in-spine',
        bookId: 'book',
        title: 'First',
        order: 0,
        blocks: [],
      ),
    ];
    final json = chapters.map(BookRecordCodec.encodeChapter).toList();
    final restored = json.map(BookRecordCodec.decodeChapter).toList();

    expect(restored.map((chapter) => chapter.id), [
      'second-in-spine',
      'first-in-spine',
    ]);
    expect(restored.map((chapter) => chapter.order), [1, 0]);
  });

  test('canonical model JSON contains no visual page fields', () {
    const chapter = Chapter(
      id: 'chapter',
      bookId: 'book',
      title: 'Chapter',
      order: 0,
      blocks: [],
    );

    expect(
      jsonEncode(BookRecordCodec.encodeChapter(chapter)).toLowerCase(),
      isNot(contains('page')),
    );
  });
}
