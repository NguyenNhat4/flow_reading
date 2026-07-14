import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flow_reading/features/import/domain/language_detection.dart';
import 'package:flow_reading/shared/domain/book.dart';
import 'package:flow_reading/shared/domain/repositories.dart';
import 'package:flow_reading/shared/domain/stable_id.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

enum EpubImportErrorKind { malformed, unsupported, drm, unsafe, tooLarge }

class EpubImportException implements Exception {
  const EpubImportException(this.kind, this.message);
  final EpubImportErrorKind kind;
  final String message;
  @override
  String toString() => message;
}

class EpubParser implements CanonicalBookParser {
  EpubParser({LanguageDetectionService? languageDetector})
    : _languageDetector =
          languageDetector ?? const HeuristicLanguageDetectionService();

  static const maxSourceBytes = 100 * 1024 * 1024;
  static const maxExpandedBytes = 500 * 1024 * 1024;
  static const maxEntries = 10000;

  final LanguageDetectionService _languageDetector;

  @override
  Future<Book> parse(
    Uint8List sourceBytes, {
    required String sourcePath,
  }) async {
    if (sourceBytes.length > maxSourceBytes) {
      throw const EpubImportException(
        EpubImportErrorKind.tooLarge,
        'This EPUB is larger than the 100 MB import limit.',
      );
    }
    final fingerprint = StableId.source(sourceBytes);
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(sourceBytes, verify: true);
    } catch (_) {
      throw const EpubImportException(
        EpubImportErrorKind.malformed,
        'The selected file is not a readable EPUB archive.',
      );
    }
    _validateArchive(archive);
    final entries = <String, ArchiveFile>{
      for (final file in archive.where((entry) => entry.isFile))
        _normalizeEntry(file.name): file,
    };
    final mimetype = _readText(entries, 'mimetype').trim();
    if (mimetype != 'application/epub+zip') {
      throw const EpubImportException(
        EpubImportErrorKind.malformed,
        'The EPUB mimetype entry is missing or invalid.',
      );
    }
    _validateEncryption(entries);
    final container = _parseXml(
      _readText(entries, 'META-INF/container.xml'),
      'container document',
    );
    final rootfile = container.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'rootfile')
        .map((element) => element.getAttribute('full-path'))
        .whereType<String>()
        .firstOrNull;
    if (rootfile == null) {
      throw const EpubImportException(
        EpubImportErrorKind.malformed,
        'The EPUB container does not identify a package document.',
      );
    }
    final packagePath = _safeArchivePath(rootfile);
    final package = _parseXml(
      _readText(entries, packagePath),
      'package document',
    );
    if (package.rootElement.name.local != 'package') {
      throw const EpubImportException(
        EpubImportErrorKind.malformed,
        'The EPUB package document is invalid.',
      );
    }

    final base = p.posix.dirname(packagePath);
    final manifest = <String, _ManifestItem>{};
    for (final item in package.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'item',
    )) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      final mediaType = item.getAttribute('media-type');
      if (id == null || href == null || mediaType == null) continue;
      final resolved = _resolve(base, href.split('#').first);
      manifest[id] = _ManifestItem(
        id: id,
        path: resolved,
        mediaType: mediaType,
        properties: (item.getAttribute('properties') ?? '')
            .split(RegExp(r'\s+'))
            .where((v) => v.isNotEmpty)
            .toSet(),
      );
    }
    if (manifest.isEmpty) {
      throw const EpubImportException(
        EpubImportErrorKind.malformed,
        'The EPUB content manifest is empty.',
      );
    }
    final spineIds = package.descendants
        .whereType<XmlElement>()
        .where(
          (e) => e.name.local == 'itemref' && e.getAttribute('linear') != 'no',
        )
        .map((e) => e.getAttribute('idref'))
        .whereType<String>()
        .toList();
    if (spineIds.isEmpty || spineIds.any((id) => !manifest.containsKey(id))) {
      throw const EpubImportException(
        EpubImportErrorKind.malformed,
        'The EPUB reading order is missing or references unknown content.',
      );
    }

    final metadata = package.descendants.whereType<XmlElement>();
    String? firstMetadata(String localName) => metadata
        .where((e) => e.name.local == localName)
        .map((e) => e.innerText.trim())
        .where((v) => v.isNotEmpty)
        .firstOrNull;
    final title = firstMetadata('title') ?? 'Untitled book';
    final authors = metadata
        .where((e) => e.name.local == 'creator')
        .map((e) => e.innerText.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    final metadataLanguage = firstMetadata('language');
    final publisher = firstMetadata('publisher');
    final description = firstMetadata('description');
    final coverManifestId = _findCoverId(package, manifest);

    final bookId = StableId.content(
      sourceFingerprint: fingerprint,
      type: CanonicalNodeType.book,
      sourceDocumentPath: packagePath,
      structuralPath: const [0],
    );
    final chapterIds = <String, String>{};
    for (var index = 0; index < spineIds.length; index++) {
      final item = manifest[spineIds[index]]!;
      if (!entries.containsKey(item.path)) {
        throw EpubImportException(
          EpubImportErrorKind.malformed,
          'A reading-order document is missing: ${item.path}',
        );
      }
      chapterIds[item.path] = StableId.content(
        sourceFingerprint: fingerprint,
        type: CanonicalNodeType.chapter,
        sourceDocumentPath: item.path,
        structuralPath: [index],
      );
    }
    final toc = _readToc(entries, package, manifest, chapterIds, fingerprint);
    final flatTocTitles = <String, String>{};
    void flatten(List<TocEntry> values) {
      for (final value in values) {
        flatTocTitles.putIfAbsent(value.chapterId, () => value.title);
        flatten(value.children);
      }
    }

    flatten(toc);

    final images = <BookImage>[];
    final imageByPath = <String, BookImage>{};
    for (final item in manifest.values.where(
      (item) => item.mediaType.startsWith('image/'),
    )) {
      if (!entries.containsKey(item.path)) continue;
      final image = BookImage(
        id: StableId.content(
          sourceFingerprint: fingerprint,
          type: CanonicalNodeType.image,
          sourceDocumentPath: item.path,
          structuralPath: const [0],
        ),
        relativePath: item.path,
        mediaType: item.mediaType,
      );
      images.add(image);
      imageByPath[item.path] = image;
    }
    final chapters = <Chapter>[];
    final representative = StringBuffer();
    for (var chapterIndex = 0; chapterIndex < spineIds.length; chapterIndex++) {
      final item = manifest[spineIds[chapterIndex]]!;
      final document = html_parser.parse(_readText(entries, item.path));
      _sanitize(document);
      final blocks = _extractBlocks(
        document,
        item.path,
        chapterIndex,
        fingerprint,
        imageByPath,
      );
      for (final block in blocks) {
        final value = block.paragraph?.text;
        if (value != null && representative.length < 30000) {
          representative.writeln(value);
        }
      }
      final chapterId = chapterIds[item.path]!;
      final heading = blocks
          .where((b) => b.kind == BlockKind.heading && b.paragraph != null)
          .map((b) => b.paragraph!.text)
          .firstOrNull;
      chapters.add(
        Chapter(
          id: chapterId,
          title:
              flatTocTitles[chapterId] ??
              heading ??
              'Chapter ${chapterIndex + 1}',
          sourceHref: item.path,
          order: chapterIndex,
          blocks: blocks,
        ),
      );
    }
    if (chapters.every((chapter) => chapter.blocks.isEmpty)) {
      throw const EpubImportException(
        EpubImportErrorKind.unsupported,
        'The EPUB contains no readable reflowable text or images.',
      );
    }
    final detection = _languageDetector.detect(
      representative.toString(),
      metadataHint: metadataLanguage,
    );
    final coverImage = coverManifestId == null
        ? null
        : imageByPath[manifest[coverManifestId]?.path]?.id;
    final initialContentId = chapters
        .expand((chapter) => chapter.blocks)
        .map((block) => block.paragraph?.id ?? block.image?.id)
        .whereType<String>()
        .first;
    final now = DateTime.now().toUtc();
    return Book(
      id: bookId,
      sourceFingerprint: fingerprint,
      sourcePath: sourcePath,
      metadata: BookMetadata(
        title: title,
        authors: authors.isEmpty ? const ['Unknown author'] : authors,
        language: detection.languageCode,
        languageConfidence: detection.confidence,
        languageSource: detection.source,
        publisher: publisher,
        description: description,
        coverImageId: coverImage,
      ),
      tableOfContents: toc.isEmpty
          ? [
              for (final chapter in chapters)
                TocEntry(
                  id: 'toc_${chapter.id}',
                  title: chapter.title,
                  chapterId: chapter.id,
                ),
            ]
          : toc,
      chapters: chapters,
      images: images,
      importedAt: now,
      readingState: ReadingState(
        bookId: bookId,
        locator: ReadingLocator(bookId: bookId, contentId: initialContentId),
        progress: 0,
        updatedAt: now,
      ),
    );
  }

  void _validateArchive(Archive archive) {
    if (archive.length > maxEntries) {
      throw const EpubImportException(
        EpubImportErrorKind.tooLarge,
        'The EPUB contains too many files.',
      );
    }
    var expanded = 0;
    final seen = <String>{};
    for (final entry in archive) {
      final normalized = _normalizeEntry(entry.name);
      if (!seen.add(normalized)) {
        throw const EpubImportException(
          EpubImportErrorKind.unsafe,
          'The EPUB contains duplicate file paths.',
        );
      }
      expanded += entry.size;
      if (expanded > maxExpandedBytes) {
        throw const EpubImportException(
          EpubImportErrorKind.tooLarge,
          'The EPUB expands beyond the safe 500 MB limit.',
        );
      }
    }
  }

  void _validateEncryption(Map<String, ArchiveFile> entries) {
    final encryption = entries['META-INF/encryption.xml'];
    if (encryption == null) return;
    final document = _parseXml(_decode(encryption), 'encryption metadata');
    final algorithms = document.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'EncryptionMethod')
        .map((e) => e.getAttribute('Algorithm'))
        .whereType<String>()
        .toList();
    const allowedFontObfuscation = {
      'http://www.idpf.org/2008/embedding',
      'http://ns.adobe.com/pdf/enc#RC',
    };
    if (algorithms.isEmpty ||
        algorithms.any((value) => !allowedFontObfuscation.contains(value))) {
      throw const EpubImportException(
        EpubImportErrorKind.drm,
        'This EPUB is protected by DRM and cannot be imported.',
      );
    }
  }

  List<ContentBlock> _extractBlocks(
    dom.Document document,
    String sourcePath,
    int chapterIndex,
    String fingerprint,
    Map<String, BookImage> images,
  ) {
    const textTags = {
      'p',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'li',
      'blockquote',
      'pre',
    };
    final candidates =
        document.body?.querySelectorAll('${textTags.join(',')},img,hr') ??
        const <dom.Element>[];
    final blocks = <ContentBlock>[];
    var ordinal = 0;
    for (final element in candidates) {
      if (element.localName == 'img') {
        final source = element.attributes['src'];
        if (source == null ||
            source.startsWith('data:') ||
            source.contains('://')) {
          continue;
        }
        final resolved = _resolve(
          p.posix.dirname(sourcePath),
          source.split('#').first,
        );
        final image = images[resolved];
        if (image == null) continue;
        blocks.add(
          ContentBlock(
            id: StableId.content(
              sourceFingerprint: fingerprint,
              type: CanonicalNodeType.block,
              sourceDocumentPath: sourcePath,
              structuralPath: [chapterIndex, ordinal],
            ),
            kind: BlockKind.image,
            image: BookImage(
              id: image.id,
              relativePath: image.relativePath,
              mediaType: image.mediaType,
              altText: element.attributes['alt'],
            ),
          ),
        );
        ordinal++;
        continue;
      }
      if (element.localName == 'hr') {
        blocks.add(
          ContentBlock(
            id: StableId.content(
              sourceFingerprint: fingerprint,
              type: CanonicalNodeType.block,
              sourceDocumentPath: sourcePath,
              structuralPath: [chapterIndex, ordinal],
            ),
            kind: BlockKind.divider,
          ),
        );
        ordinal++;
        continue;
      }
      final built = _buildFormattedText(element);
      if (built.text.isEmpty) continue;
      final path = [chapterIndex, ordinal];
      final paragraphId = StableId.content(
        sourceFingerprint: fingerprint,
        type: CanonicalNodeType.paragraph,
        sourceDocumentPath: sourcePath,
        structuralPath: path,
      );
      final sentences = _sentences(built.text, fingerprint, sourcePath, path);
      final kind = element.localName?.startsWith('h') == true
          ? BlockKind.heading
          : element.localName == 'li'
          ? BlockKind.listItem
          : BlockKind.paragraph;
      blocks.add(
        ContentBlock(
          id: StableId.content(
            sourceFingerprint: fingerprint,
            type: CanonicalNodeType.block,
            sourceDocumentPath: sourcePath,
            structuralPath: path,
          ),
          kind: kind,
          paragraph: Paragraph(
            id: paragraphId,
            text: built.text,
            sentences: sentences,
            formats: built.formats,
            alignment: _alignment(element),
          ),
        ),
      );
      ordinal++;
    }
    return blocks;
  }

  _BuiltText _buildFormattedText(dom.Element root) {
    final buffer = StringBuffer();
    final formats = <TextFormat>[];
    void visit(
      dom.Node node, {
      bool bold = false,
      bool italic = false,
      bool underline = false,
      String? link,
    }) {
      if (node is dom.Text) {
        var text = node.data.replaceAll(RegExp(r'\s+'), ' ');
        if (buffer.isEmpty) text = text.replaceFirst(RegExp(r'^\s+'), '');
        if (buffer.toString().endsWith(' ') && text.startsWith(' ')) {
          text = text.substring(1);
        }
        final start = buffer.length;
        buffer.write(text);
        final end = buffer.length;
        if (end > start && (bold || italic || underline || link != null)) {
          formats.add(
            TextFormat(
              start: start,
              end: end,
              bold: bold,
              italic: italic,
              underline: underline,
              link: link,
            ),
          );
        }
        return;
      }
      if (node is! dom.Element) return;
      final tag = node.localName;
      final href = node.attributes['href'];
      final safeLink =
          href != null &&
              !href.contains('://') &&
              !href.toLowerCase().startsWith('javascript:')
          ? href
          : null;
      for (final child in node.nodes) {
        visit(
          child,
          bold: bold || tag == 'b' || tag == 'strong',
          italic: italic || tag == 'i' || tag == 'em',
          underline: underline || tag == 'u',
          link: link ?? safeLink,
        );
      }
    }

    for (final node in root.nodes) {
      visit(node);
    }
    final raw = buffer.toString();
    final trimmedRight = raw.replaceFirst(RegExp(r'\s+$'), '');
    return _BuiltText(trimmedRight, [
      for (final format in formats)
        if (format.start < trimmedRight.length)
          TextFormat(
            start: format.start,
            end: format.end.clamp(0, trimmedRight.length),
            bold: format.bold,
            italic: format.italic,
            underline: format.underline,
            link: format.link,
          ),
    ]);
  }

  List<Sentence> _sentences(
    String text,
    String fingerprint,
    String path,
    List<int> paragraphPath,
  ) {
    final matches = RegExp(
      r'[^.!?…。！？]+(?:[.!?…。！？]+(?=\s|$)|$)',
      unicode: true,
    ).allMatches(text).toList();
    final segments = matches.isEmpty
        ? [RegExp(r'.+', dotAll: true).firstMatch(text)!]
        : matches;
    final sentences = <Sentence>[];
    for (var index = 0; index < segments.length; index++) {
      final value = segments[index].group(0)!.trim();
      if (value.isEmpty) continue;
      final sentenceId = StableId.content(
        sourceFingerprint: fingerprint,
        type: CanonicalNodeType.sentence,
        sourceDocumentPath: path,
        structuralPath: [...paragraphPath, index],
      );
      final words = <Word>[];
      final wordMatches = RegExp(
        r"[\p{L}\p{N}]+(?:['’\-][\p{L}\p{N}]+)*",
        unicode: true,
      ).allMatches(value);
      var wordIndex = 0;
      for (final match in wordMatches) {
        words.add(
          Word(
            id: StableId.content(
              sourceFingerprint: fingerprint,
              type: CanonicalNodeType.word,
              sourceDocumentPath: path,
              structuralPath: [...paragraphPath, index, wordIndex++],
            ),
            text: match.group(0)!,
            start: match.start,
            end: match.end,
          ),
        );
      }
      sentences.add(Sentence(id: sentenceId, text: value, words: words));
    }
    return sentences;
  }

  List<TocEntry> _readToc(
    Map<String, ArchiveFile> entries,
    XmlDocument package,
    Map<String, _ManifestItem> manifest,
    Map<String, String> chapterIds,
    String fingerprint,
  ) {
    final nav = manifest.values
        .where((item) => item.properties.contains('nav'))
        .firstOrNull;
    if (nav != null && entries.containsKey(nav.path)) {
      final document = html_parser.parse(_readText(entries, nav.path));
      final tocNav =
          document.querySelector(
            'nav[epub\\:type="toc"], nav[role="doc-toc"]',
          ) ??
          document.querySelector('nav');
      final rootList = tocNav?.children
          .where((e) => e.localName == 'ol')
          .firstOrNull;
      if (rootList != null) {
        return _htmlToc(rootList, nav.path, chapterIds, fingerprint, const []);
      }
    }
    final spine = package.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'spine')
        .firstOrNull;
    final ncxId = spine?.getAttribute('toc');
    final ncx = ncxId == null ? null : manifest[ncxId];
    if (ncx != null && entries.containsKey(ncx.path)) {
      final document = _parseXml(
        _readText(entries, ncx.path),
        'NCX table of contents',
      );
      final points = document.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'navMap')
          .firstOrNull;
      if (points != null) {
        return _xmlToc(points, ncx.path, chapterIds, fingerprint, const []);
      }
    }
    return const [];
  }

  List<TocEntry> _htmlToc(
    dom.Element list,
    String tocPath,
    Map<String, String> chapterIds,
    String fingerprint,
    List<int> parentPath,
  ) {
    final result = <TocEntry>[];
    final items = list.children.where((e) => e.localName == 'li').toList();
    for (var index = 0; index < items.length; index++) {
      final li = items[index];
      final anchor = li.children.where((e) => e.localName == 'a').firstOrNull;
      final href = anchor?.attributes['href'];
      if (href == null) continue;
      final parts = href.split('#');
      final chapterPath = _resolve(p.posix.dirname(tocPath), parts.first);
      final chapterId = chapterIds[chapterPath];
      if (chapterId == null) continue;
      final nested = li.children.where((e) => e.localName == 'ol').firstOrNull;
      final structural = [...parentPath, index];
      result.add(
        TocEntry(
          id: StableId.content(
            sourceFingerprint: fingerprint,
            type: CanonicalNodeType.block,
            sourceDocumentPath: tocPath,
            structuralPath: structural,
          ),
          title: anchor!.text.trim().isEmpty
              ? 'Untitled section'
              : anchor.text.trim(),
          chapterId: chapterId,
          fragment: parts.length > 1 ? parts[1] : null,
          children: nested == null
              ? const []
              : _htmlToc(nested, tocPath, chapterIds, fingerprint, structural),
        ),
      );
    }
    return result;
  }

  List<TocEntry> _xmlToc(
    XmlElement parent,
    String tocPath,
    Map<String, String> chapterIds,
    String fingerprint,
    List<int> parentPath,
  ) {
    final result = <TocEntry>[];
    final points = parent.childElements
        .where((e) => e.name.local == 'navPoint')
        .toList();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final content = point.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'content')
          .firstOrNull;
      final label = point.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'text')
          .firstOrNull
          ?.innerText
          .trim();
      final src = content?.getAttribute('src');
      if (src == null) continue;
      final parts = src.split('#');
      final chapterPath = _resolve(p.posix.dirname(tocPath), parts.first);
      final chapterId = chapterIds[chapterPath];
      if (chapterId == null) continue;
      final structural = [...parentPath, index];
      result.add(
        TocEntry(
          id: StableId.content(
            sourceFingerprint: fingerprint,
            type: CanonicalNodeType.block,
            sourceDocumentPath: tocPath,
            structuralPath: structural,
          ),
          title: label?.isNotEmpty == true ? label! : 'Untitled section',
          chapterId: chapterId,
          fragment: parts.length > 1 ? parts[1] : null,
          children: _xmlToc(
            point,
            tocPath,
            chapterIds,
            fingerprint,
            structural,
          ),
        ),
      );
    }
    return result;
  }

  String? _findCoverId(
    XmlDocument package,
    Map<String, _ManifestItem> manifest,
  ) {
    final propertyCover = manifest.values
        .where((item) => item.properties.contains('cover-image'))
        .firstOrNull;
    if (propertyCover != null) return propertyCover.id;
    return package.descendants
        .whereType<XmlElement>()
        .where(
          (e) =>
              e.name.local == 'meta' &&
              e.getAttribute('name')?.toLowerCase() == 'cover',
        )
        .map((e) => e.getAttribute('content'))
        .whereType<String>()
        .firstOrNull;
  }

  void _sanitize(dom.Document document) {
    for (final element in document.querySelectorAll(
      'script,style,iframe,object,embed,form,input,button,video,audio,svg,canvas',
    )) {
      element.remove();
    }
    for (final element in document.querySelectorAll('*')) {
      element.attributes.removeWhere((key, value) {
        final name = key.toString().toLowerCase();
        return name.startsWith('on') || name == 'style' || name == 'srcset';
      });
    }
  }

  TextAlignment _alignment(dom.Element element) {
    dom.Element? current = element;
    while (current != null) {
      final direction = current.attributes['dir']?.toLowerCase();
      if (direction == 'rtl') return TextAlignment.end;
      if (direction == 'ltr') return TextAlignment.start;
      current = current.parent;
    }
    return TextAlignment.start;
  }

  XmlDocument _parseXml(String value, String label) {
    try {
      return XmlDocument.parse(value);
    } catch (_) {
      throw EpubImportException(
        EpubImportErrorKind.malformed,
        'The EPUB $label is malformed.',
      );
    }
  }

  String _readText(Map<String, ArchiveFile> entries, String path) {
    final entry = entries[_safeArchivePath(path)];
    if (entry == null) {
      throw EpubImportException(
        EpubImportErrorKind.malformed,
        'A required EPUB file is missing: $path',
      );
    }
    return _decode(entry);
  }

  String _decode(ArchiveFile entry) {
    try {
      final bytes = entry.readBytes();
      if (bytes == null) throw StateError('No entry bytes');
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      throw const EpubImportException(
        EpubImportErrorKind.drm,
        'An encrypted EPUB resource could not be read. DRM-protected books are unsupported.',
      );
    }
  }

  String _resolve(String base, String href) =>
      _safeArchivePath(p.posix.join(base, Uri.decodeComponent(href)));

  String _normalizeEntry(String value) =>
      _safeArchivePath(value.replaceAll('\\', '/'));

  String _safeArchivePath(String value) {
    final normalized = p.posix.normalize(value.replaceAll('\\', '/'));
    if (normalized == '.' ||
        normalized.startsWith('../') ||
        normalized.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) {
      throw const EpubImportException(
        EpubImportErrorKind.unsafe,
        'The EPUB contains an unsafe file path.',
      );
    }
    return normalized;
  }
}

class _ManifestItem {
  const _ManifestItem({
    required this.id,
    required this.path,
    required this.mediaType,
    required this.properties,
  });
  final String id;
  final String path;
  final String mediaType;
  final Set<String> properties;
}

class _BuiltText {
  const _BuiltText(this.text, this.formats);
  final String text;
  final List<TextFormat> formats;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
