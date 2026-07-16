import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flow_reading/data/services/canonical_html_converter.dart';
import 'package:flow_reading/data/services/epub_package_parser.dart';
import 'package:flow_reading/data/services/epub_validator.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'converts complex malformed HTML in source order and removes unsafe content',
    () {
      final validated = EpubValidator.validate(_epub());
      final draft = EpubPackageParser.parse(
        validated,
        bookId: 'book_id',
        sourceFileName: 'book.epub',
      );
      final content = CanonicalHtmlConverter.convert(
        validated,
        draft,
        assetLocalPath: (id, href) => '/books/book_id/assets/$id.jpg',
      );
      final blocks = content.chapters.single.blocks;

      expect(blocks.map((block) => block.runtimeType), [
        HeadingBlock,
        ParagraphBlock,
        QuoteBlock,
        ListBlock,
        ImageBlock,
      ]);
      final paragraph = blocks[1] as ParagraphBlock;
      expect(paragraph.text, 'Read carefully.');
      expect(paragraph.spans.any((span) => span.italic), isTrue);
      expect(paragraph.spans.any((span) => span.href == 'note.xhtml'), isTrue);
      expect(
        blocks.whereType<ParagraphBlock>().map((block) => block.text),
        isNot(contains('unsafe')),
      );
      final list = blocks[3] as ListBlock;
      expect(list.items.single.text, 'First');
      expect(list.items.single.children.single.text, 'Nested');
      expect(content.assets.single.asset.sourceHref, 'EPUB/images/picture.jpg');
      expect(content.assets.single.bytes, [1, 2, 3]);
      expect(content.tableOfContents.single.reference.blockId, blocks.first.id);
    },
  );

  test('missing image produces a readable invalid EPUB failure', () {
    final validated = EpubValidator.validate(_epub(includeImage: false));
    final draft = EpubPackageParser.parse(
      validated,
      bookId: 'book_id',
      sourceFileName: 'book.epub',
    );

    expect(
      () => CanonicalHtmlConverter.convert(
        validated,
        draft,
        assetLocalPath: (id, href) => '/assets/$id',
      ),
      throwsA(isA<InvalidEpubFailure>()),
    );
  });
}

Uint8List _epub({bool includeImage = true}) {
  final chapter = '''<html><body>
<h1 id="start">Opening</h1>
<p>Read <em>carefully</em><script>unsafe</script><a href="note.xhtml">.</a></p>
<blockquote>A quotation.</blockquote>
<ol><li>First<ul><li>Nested</li></ul></li></ol>
<img src="../images/picture.jpg" alt="Picture">
</body></html>''';
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
    )
    ..add(
      ArchiveFile.string(
        'EPUB/content.opf',
        '''<package><metadata><title>Book</title></metadata><manifest>
<item id="chapter" href="text/chapter.xhtml" media-type="application/xhtml+xml"/>
<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
</manifest><spine><itemref idref="chapter"/></spine></package>''',
      ),
    )
    ..add(
      ArchiveFile.string(
        'EPUB/nav.xhtml',
        '<html><body><nav type="toc"><ol><li><a href="text/chapter.xhtml#start">Opening</a></li></ol></nav></body></html>',
      ),
    )
    ..add(ArchiveFile.string('EPUB/text/chapter.xhtml', chapter));
  if (includeImage) {
    archive.add(
      ArchiveFile.bytes(
        'EPUB/images/picture.jpg',
        Uint8List.fromList([1, 2, 3]),
      ),
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
