import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flow_reading/data/services/epub_validator.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid EPUB continues with its package and ordered spine resources', () {
    final result = EpubValidator.validate(_epub());

    expect(result.packageDocumentPath, 'EPUB/content.opf');
    expect(result.chapterResourcePaths, [
      'EPUB/text/chapter-1.xhtml',
      'EPUB/text/chapter-2.xhtml',
    ]);
  });

  test('corrupted ZIP produces a readable invalid EPUB failure', () {
    expect(
      () => EpubValidator.validate(Uint8List.fromList([1, 2, 3])),
      throwsA(
        isA<InvalidEpubFailure>().having(
          (failure) => failure.message,
          'message',
          isNotEmpty,
        ),
      ),
    );
  });

  test('invalid mimetype is rejected', () {
    expect(
      () => EpubValidator.validate(_epub(mimetype: 'application/zip')),
      throwsA(isA<InvalidEpubFailure>()),
    );
  });

  test('missing package document is rejected', () {
    expect(
      () => EpubValidator.validate(_epub(includePackage: false)),
      throwsA(
        isA<InvalidEpubFailure>().having(
          (failure) => failure.message,
          'message',
          contains('package document'),
        ),
      ),
    );
  });

  test('unknown spine manifest reference is rejected', () {
    expect(
      () => EpubValidator.validate(_epub(spineId: 'missing')),
      throwsA(
        isA<InvalidEpubFailure>().having(
          (failure) => failure.message,
          'message',
          contains('unknown resource'),
        ),
      ),
    );
  });

  test('missing chapter resource is rejected', () {
    expect(
      () => EpubValidator.validate(_epub(includeSecondChapter: false)),
      throwsA(
        isA<InvalidEpubFailure>().having(
          (failure) => failure.message,
          'message',
          contains('chapter resource'),
        ),
      ),
    );
  });

  test('encrypted EPUB produces the specific DRM failure', () {
    expect(
      () => EpubValidator.validate(_epub(encrypted: true)),
      throwsA(isA<UnsupportedDrmFailure>()),
    );
  });
}

Uint8List _epub({
  String mimetype = 'application/epub+zip',
  bool includePackage = true,
  bool includeSecondChapter = true,
  bool encrypted = false,
  String spineId = 'chapter-1',
}) {
  final archive = Archive()
    ..add(
      ArchiveFile.noCompress(
        'mimetype',
        mimetype.length,
        utf8.encode(mimetype),
      ),
    )
    ..add(
      ArchiveFile.string('META-INF/container.xml', '''<?xml version="1.0"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="EPUB/content.opf"/></rootfiles>
</container>'''),
    );
  if (includePackage) {
    archive.add(
      ArchiveFile.string('EPUB/content.opf', '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf">
  <manifest>
    <item id="chapter-1" href="text/chapter-1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter-2" href="text/chapter-2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="$spineId"/>
    <itemref idref="chapter-2"/>
  </spine>
</package>'''),
    );
  }
  archive.add(ArchiveFile.string('EPUB/text/chapter-1.xhtml', '<p>One</p>'));
  if (includeSecondChapter) {
    archive.add(ArchiveFile.string('EPUB/text/chapter-2.xhtml', '<p>Two</p>'));
  }
  if (encrypted) {
    archive.add(
      ArchiveFile.string(
        'META-INF/encryption.xml',
        '<encryption><EncryptedData><EncryptionMethod/></EncryptedData></encryption>',
      ),
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
