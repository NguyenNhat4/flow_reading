import 'dart:typed_data';

import 'package:flow_reading/features/import/data/epub_parser.dart';
import 'package:flow_reading/shared/domain/book.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/epub_fixture.dart';

void main() {
  final parser = EpubParser();

  test(
    'imports metadata, nested TOC, formatting, images, and stable content',
    () async {
      final book = await parser.parse(
        epubFixture(nestedToc: true, imageCount: 12),
        sourcePath: 'fixture.epub',
      );
      expect(book.metadata.title, 'Fixture Book');
      expect(book.metadata.authors, ['Fixture Author']);
      expect(book.metadata.language, 'en');
      expect(book.metadata.languageConfidence, greaterThan(.5));
      expect(book.tableOfContents.single.children.single.title, 'Nested Part');
      expect(book.images, hasLength(12));
      expect(book.metadata.coverImageId, isNotNull);
      expect(
        book.chapters.single.blocks
            .where((block) => block.paragraph != null)
            .expand((block) => block.paragraph!.formats),
        isNotEmpty,
      );
      expect(
        book.chapters.single.blocks.any(
          (block) => block.kind == BlockKind.image,
        ),
        isTrue,
      );
      expect(
        book.chapters.single.blocks.map((block) => block.id).toSet(),
        hasLength(book.chapters.single.blocks.length),
      );
    },
  );

  test('uses readable fallbacks when metadata is missing', () async {
    final book = await parser.parse(
      epubFixture(includeMetadata: false),
      sourcePath: 'missing-metadata.epub',
    );
    expect(book.metadata.title, 'Untitled book');
    expect(book.metadata.authors, ['Unknown author']);
    expect(book.metadata.language, 'en');
  });

  test('handles RTL and Unicode text', () async {
    final book = await parser.parse(
      epubFixture(rtl: true),
      sourcePath: 'arabic.epub',
    );
    expect(book.metadata.language, 'ar');
    expect(
      book.chapters.single.blocks
          .where((block) => block.paragraph != null)
          .any((block) => block.paragraph!.alignment == TextAlignment.end),
      isTrue,
    );
  });

  test('rejects malformed archives with a readable typed error', () async {
    await expectLater(
      parser.parse(Uint8List.fromList([1, 2, 3]), sourcePath: 'bad.epub'),
      throwsA(
        isA<EpubImportException>().having(
          (error) => error.kind,
          'kind',
          EpubImportErrorKind.malformed,
        ),
      ),
    );
  });

  test('rejects DRM before creating a canonical book', () async {
    await expectLater(
      parser.parse(epubFixture(drm: true), sourcePath: 'drm.epub'),
      throwsA(
        isA<EpubImportException>().having(
          (error) => error.kind,
          'kind',
          EpubImportErrorKind.drm,
        ),
      ),
    );
  });
}
