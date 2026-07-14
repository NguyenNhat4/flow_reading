import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

Uint8List epubFixture({
  bool includeMetadata = true,
  bool nestedToc = false,
  bool rtl = false,
  int imageCount = 1,
  bool drm = false,
}) {
  final archive = Archive();
  archive.add(
    ArchiveFile.noCompress(
      'mimetype',
      'application/epub+zip'.length,
      utf8.encode('application/epub+zip'),
    ),
  );
  archive.add(
    ArchiveFile.string('META-INF/container.xml', '''
    <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles><rootfile full-path="EPUB/package.opf" media-type="application/oebps-package+xml"/></rootfiles>
    </container>
  '''),
  );
  if (drm) {
    archive.add(
      ArchiveFile.string('META-INF/encryption.xml', '''
      <encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <EncryptedData><EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes256-cbc"/></EncryptedData>
      </encryption>
    '''),
    );
  }
  final imageManifest = StringBuffer();
  for (var index = 0; index < imageCount; index++) {
    imageManifest.writeln(
      '<item id="image$index" href="images/image$index.png" media-type="image/png" ${index == 0 ? 'properties="cover-image"' : ''}/>',
    );
    archive.add(ArchiveFile.bytes('EPUB/images/image$index.png', _onePixelPng));
  }
  archive.add(
    ArchiveFile.string('EPUB/package.opf', '''
    <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uid" version="3.0">
      <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:identifier id="uid">fixture-id</dc:identifier>
        ${includeMetadata ? '<dc:title>Fixture Book</dc:title><dc:creator>Fixture Author</dc:creator><dc:language>${rtl ? 'ar' : 'en'}</dc:language>' : ''}
      </metadata>
      <manifest>
        <item id="chapter" href="text/chapter.xhtml" media-type="application/xhtml+xml"/>
        <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
        $imageManifest
      </manifest>
      <spine><itemref idref="chapter"/></spine>
    </package>
  '''),
  );
  archive.add(
    ArchiveFile.string('EPUB/nav.xhtml', '''
    <html xmlns="http://www.w3.org/1999/xhtml"><body>
      <nav role="doc-toc"><ol>
        <li><a href="text/chapter.xhtml">Chapter One</a>
          ${nestedToc ? '<ol><li><a href="text/chapter.xhtml#part">Nested Part</a></li></ol>' : ''}
        </li>
      </ol></nav>
    </body></html>
  '''),
  );
  archive.add(
    ArchiveFile.string('EPUB/text/chapter.xhtml', '''
    <html xmlns="http://www.w3.org/1999/xhtml"><body ${rtl ? 'dir="rtl"' : ''}>
      <script>window.evil = true;</script>
      <h1>Chapter One</h1>
      <p>${rtl ? 'هذا كتاب عربي وهذا نص للاختبار والقراءة باللغة العربية.' : 'The reader follows the flow of a story and keeps the current place.'}</p>
      <p><strong>Bold words</strong> and <em>gentle emphasis</em>.</p>
      <img src="../images/image0.png" alt="A fixture cover" onload="steal()"/>
    </body></html>
  '''),
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
