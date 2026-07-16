import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flow_reading/books/epub_package_parser.dart';
import 'package:flow_reading/books/epub_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses EPUB 3 metadata, cover, spine, and nested navigation', () {
    final epub = EpubValidator.validate(_epub3());
    final draft = EpubPackageParser.parse(
      epub,
      bookId: 'book_id',
      sourceFileName: 'fallback.epub',
    );

    expect(draft.metadata.title, 'Canonical Book');
    expect(draft.metadata.authors, ['Author One', 'Author Two']);
    expect(draft.metadata.language, 'en');
    expect(draft.metadata.coverAssetId, draft.cover?.id);
    expect(draft.cover?.bytes, [7, 8, 9]);
    expect(draft.chapters.map((chapter) => chapter.title), [
      'Opening',
      'Second',
    ]);
    expect(draft.chapters.map((chapter) => chapter.order), [0, 1]);
    expect(
      draft.tableOfContents.first.reference.chapterId,
      draft.chapters.first.id,
    );
    expect(draft.tableOfContents.first.reference.fragment, 'start');
    expect(draft.tableOfContents.first.children.single.title, 'Second');
  });

  test(
    'uses filename and spine paths when optional metadata and TOC are absent',
    () {
      final epub = EpubValidator.validate(_minimalEpub());
      final draft = EpubPackageParser.parse(
        epub,
        bookId: 'book_id',
        sourceFileName: 'My Story.EPUB',
      );

      expect(draft.metadata.title, 'My Story');
      expect(draft.metadata.authors, isEmpty);
      expect(draft.metadata.language, isNull);
      expect(draft.cover, isNull);
      expect(draft.chapters.single.title, 'chapter');
      expect(draft.tableOfContents, isEmpty);
    },
  );

  test('uses an EPUB 2 NCX table of contents when navigation is absent', () {
    final epub = EpubValidator.validate(_epub2());
    final draft = EpubPackageParser.parse(
      epub,
      bookId: 'book_id',
      sourceFileName: 'legacy.epub',
    );

    expect(draft.tableOfContents.single.title, 'Legacy Chapter');
    expect(
      draft.tableOfContents.single.reference.chapterId,
      draft.chapters.single.id,
    );
  });
}

Uint8List _epub3() {
  return _zip({
    'EPUB/content.opf': '''<package xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Canonical Book</dc:title><dc:creator>Author One</dc:creator>
    <dc:creator>Author Two</dc:creator><dc:language>en</dc:language>
    <dc:identifier>identifier</dc:identifier>
  </metadata>
  <manifest>
    <item id="one" href="text/one.xhtml" media-type="application/xhtml+xml"/>
    <item id="two" href="text/two.xhtml" media-type="application/xhtml+xml"/>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="cover" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>
  </manifest>
  <spine><itemref idref="one"/><itemref idref="two"/></spine>
</package>''',
    'EPUB/nav.xhtml':
        '''<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body><nav epub:type="toc"><ol><li><a href="text/one.xhtml#start">Opening</a>
  <ol><li><a href="text/two.xhtml">Second</a></li></ol></li></ol></nav></body>
</html>''',
    'EPUB/text/one.xhtml': '<html><body>One</body></html>',
    'EPUB/text/two.xhtml': '<html><body>Two</body></html>',
    'EPUB/images/cover.jpg': Uint8List.fromList([7, 8, 9]),
  });
}

Uint8List _minimalEpub() {
  return _zip({
    'EPUB/content.opf': '''<package xmlns="http://www.idpf.org/2007/opf">
  <metadata/><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="chapter"/></spine>
</package>''',
    'EPUB/chapter.xhtml': '<html><body>Chapter</body></html>',
  });
}

Uint8List _epub2() {
  return _zip({
    'EPUB/content.opf': '''<package xmlns="http://www.idpf.org/2007/opf">
  <metadata/><manifest>
    <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
  </manifest><spine toc="ncx"><itemref idref="chapter"/></spine>
</package>''',
    'EPUB/chapter.xhtml': '<html><body>Legacy</body></html>',
    'EPUB/toc.ncx': '''<ncx><navMap><navPoint>
  <navLabel><text>Legacy Chapter</text></navLabel>
  <content src="chapter.xhtml"/>
</navPoint></navMap></ncx>''',
  });
}

Uint8List _zip(Map<String, Object> resources) {
  final archive = Archive()
    ..add(
      ArchiveFile.noCompress(
        'mimetype',
        20,
        utf8.encode('application/epub+zip'),
      ),
    )
    ..add(
      ArchiveFile.string(
        'META-INF/container.xml',
        '<container><rootfiles><rootfile full-path="EPUB/content.opf"/></rootfiles></container>',
      ),
    );
  for (final entry in resources.entries) {
    final value = entry.value;
    archive.add(
      value is String
          ? ArchiveFile.string(entry.key, value)
          : ArchiveFile.bytes(entry.key, value as Uint8List),
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
