import 'package:flow_reading/features/reader/domain/pagination.dart';
import 'package:flow_reading/shared/domain/book.dart';
import 'package:flow_reading/shared/domain/stable_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'large-chapter repagination is fast and preserves stable references',
    () {
      final book = _longBook();
      const engine = PaginationEngine();
      final paragraph = book.chapters.single.blocks.single.paragraph!;
      final locator = ReadingLocator(
        bookId: book.id,
        contentId: paragraph.id,
        characterOffset: paragraph.text.length ~/ 2,
      );
      final annotation = Annotation(
        id: 'highlight',
        bookId: book.id,
        kind: AnnotationKind.highlight,
        start: locator,
        end: ReadingLocator(
          bookId: book.id,
          contentId: paragraph.id,
          characterOffset: locator.characterOffset + 12,
        ),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      final stopwatch = Stopwatch()..start();
      final portrait = engine.paginate(
        book: book,
        viewport: const Size(360, 620),
        settings: const ReaderSettings(fontSize: 16, horizontalMargin: 16),
      );
      final landscape = engine.paginate(
        book: book,
        viewport: const Size(760, 340),
        settings: const ReaderSettings(
          fontSize: 25,
          horizontalMargin: 56,
          theme: ReaderTheme.dark,
        ),
      );
      stopwatch.stop();
      expect(portrait.pages.length, greaterThan(1));
      expect(landscape.pages.length, greaterThan(1));
      final portraitPage = portrait.pages[portrait.pageFor(locator, book)];
      final landscapePage = landscape.pages[landscape.pageFor(locator, book)];
      expect(
        portraitPage.slices.any((slice) => slice.contentId == paragraph.id),
        isTrue,
      );
      expect(
        landscapePage.slices.any((slice) => slice.contentId == paragraph.id),
        isTrue,
      );
      expect(annotation.start.contentId, paragraph.id);
      expect(annotation.start.characterOffset, locator.characterOffset);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
    },
  );
}

Book _longBook() {
  const fingerprint =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  final paragraphId = StableId.content(
    sourceFingerprint: fingerprint,
    type: CanonicalNodeType.paragraph,
    sourceDocumentPath: 'chapter.xhtml',
    structuralPath: const [0, 0],
  );
  final text = List.filled(
    180,
    'A stable locator follows the canonical text instead of a visual page number.',
  ).join(' ');
  return Book(
    id: 'long_book',
    sourceFingerprint: fingerprint,
    sourcePath: 'long.epub',
    metadata: const BookMetadata(
      title: 'Long Book',
      authors: ['Author'],
      language: 'en',
    ),
    tableOfContents: const [],
    chapters: [
      Chapter(
        id: 'chapter',
        title: 'Chapter',
        sourceHref: 'chapter.xhtml',
        order: 0,
        blocks: [
          ContentBlock(
            id: 'block',
            kind: BlockKind.paragraph,
            paragraph: Paragraph(
              id: paragraphId,
              text: text,
              sentences: const [],
            ),
          ),
        ],
      ),
    ],
    importedAt: DateTime.utc(2026),
  );
}
