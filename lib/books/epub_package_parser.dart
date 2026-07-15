import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/content_identifiers.dart';
import 'package:flow_reading/books/epub_validator.dart';
import 'package:flow_reading/shared/app_failure.dart';
import 'package:xml/xml.dart';

final class EpubChapterDraft {
  const EpubChapterDraft({
    required this.id,
    required this.sourceHref,
    required this.title,
    required this.order,
    required this.mediaType,
  });

  final String id;
  final String sourceHref;
  final String title;
  final int order;
  final String mediaType;
}

final class EpubAssetDraft {
  const EpubAssetDraft({
    required this.id,
    required this.sourceHref,
    required this.mediaType,
    required this.bytes,
  });

  final String id;
  final String sourceHref;
  final String mediaType;
  final Uint8List bytes;
}

final class EpubImportDraft {
  const EpubImportDraft({
    required this.metadata,
    required this.chapters,
    required this.tableOfContents,
    this.cover,
  });

  final BookMetadata metadata;
  final List<EpubChapterDraft> chapters;
  final List<TableOfContentsEntry> tableOfContents;
  final EpubAssetDraft? cover;
}

abstract final class EpubPackageParser {
  static EpubImportDraft parse(
    ValidatedEpub epub, {
    required String bookId,
    required String sourceFileName,
  }) {
    try {
      final package = _readXml(epub.archive, epub.packageDocumentPath);
      final manifestElement = package.findAllElements('manifest').first;
      final spineElement = package.findAllElements('spine').first;
      final manifest = _manifest(manifestElement);
      final packageDirectory = Uri(path: epub.packageDocumentPath).resolve('.');

      final chapterItems = <_ManifestItem>[];
      for (final itemRef in spineElement.findElements('itemref')) {
        final idref = itemRef.getAttribute('idref');
        final item = idref == null ? null : manifest[idref];
        if (item == null) {
          throw const InvalidEpubFailure(
            message: 'The EPUB spine references an unknown resource.',
          );
        }
        chapterItems.add(item);
      }

      final navigation = _readNavigation(
        epub.archive,
        packageDirectory,
        manifest,
        spineElement,
      );
      final navigationTitles = <String, String>{};
      void collectTitles(List<_NavigationEntry> entries) {
        for (final entry in entries) {
          navigationTitles.putIfAbsent(entry.path, () => entry.title);
          collectTitles(entry.children);
        }
      }

      collectTitles(navigation);
      final chapters = <EpubChapterDraft>[];
      final chapterIdsByPath = <String, String>{};
      for (var index = 0; index < chapterItems.length; index++) {
        final item = chapterItems[index];
        final path = packageDirectory.resolve(item.href).normalizePath().path;
        final chapterId = ContentIdentifiers.chapter(
          bookId: bookId,
          spineIndex: index,
          sourceHref: path,
        );
        chapterIdsByPath[path] = chapterId;
        chapters.add(
          EpubChapterDraft(
            id: chapterId,
            sourceHref: path,
            title: navigationTitles[path] ?? _titleFromPath(path),
            order: index,
            mediaType: item.mediaType,
          ),
        );
      }

      final tableOfContents = _toTableOfContents(navigation, chapterIdsByPath);
      final coverItem = _findCover(package, manifest);
      final cover = coverItem == null
          ? null
          : _asset(epub.archive, packageDirectory, bookId, coverItem);
      final metadata = _metadata(
        package,
        sourceFileName,
        coverAssetId: cover?.id,
      );

      return EpubImportDraft(
        metadata: metadata,
        chapters: List.unmodifiable(chapters),
        tableOfContents: List.unmodifiable(tableOfContents),
        cover: cover,
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const InvalidEpubFailure(
        message: 'The EPUB metadata or table of contents could not be read.',
      );
    }
  }

  static BookMetadata _metadata(
    XmlDocument package,
    String sourceFileName, {
    required String? coverAssetId,
  }) {
    final metadata = package.findAllElements('metadata').first;
    String? firstText(String name) {
      final elements = _elementsByLocalName(metadata, name);
      if (elements.isEmpty) return null;
      final value = elements.first.innerText.trim();
      return value.isEmpty ? null : value;
    }

    final authors = _elementsByLocalName(metadata, 'creator')
        .map((element) => element.innerText.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final title = firstText('title') ?? _titleFromFileName(sourceFileName);
    return BookMetadata(
      title: title,
      authors: List.unmodifiable(authors),
      language: firstText('language'),
      identifier: firstText('identifier'),
      publisher: firstText('publisher'),
      description: firstText('description'),
      coverAssetId: coverAssetId,
    );
  }

  static Map<String, _ManifestItem> _manifest(XmlElement manifest) {
    return {
      for (final item in manifest.findElements('item'))
        if ((item.getAttribute('id') ?? '').isNotEmpty &&
            (item.getAttribute('href') ?? '').isNotEmpty)
          item.getAttribute('id')!: _ManifestItem(
            id: item.getAttribute('id')!,
            href: item.getAttribute('href')!,
            mediaType: item.getAttribute('media-type') ?? '',
            properties: (item.getAttribute('properties') ?? '')
                .split(RegExp(r'\s+'))
                .where((value) => value.isNotEmpty)
                .toSet(),
          ),
    };
  }

  static _ManifestItem? _findCover(
    XmlDocument package,
    Map<String, _ManifestItem> manifest,
  ) {
    for (final item in manifest.values) {
      if (item.properties.contains('cover-image')) return item;
    }
    for (final meta in package.findAllElements('meta')) {
      if (meta.getAttribute('name') == 'cover') {
        return manifest[meta.getAttribute('content')];
      }
    }
    return null;
  }

  static EpubAssetDraft _asset(
    Archive archive,
    Uri packageDirectory,
    String bookId,
    _ManifestItem item,
  ) {
    final path = packageDirectory.resolve(item.href).normalizePath().path;
    final file = archive.find(path);
    if (file == null) {
      throw const InvalidEpubFailure(message: 'The EPUB cover is missing.');
    }
    return EpubAssetDraft(
      id: ContentIdentifiers.asset(bookId: bookId, sourceHref: path),
      sourceHref: path,
      mediaType: item.mediaType,
      bytes: file.readBytes()!,
    );
  }

  static List<_NavigationEntry> _readNavigation(
    Archive archive,
    Uri packageDirectory,
    Map<String, _ManifestItem> manifest,
    XmlElement spine,
  ) {
    final navItem = manifest.values
        .where((item) => item.properties.contains('nav'))
        .firstOrNull;
    if (navItem != null) {
      final navPath = packageDirectory
          .resolve(navItem.href)
          .normalizePath()
          .path;
      final document = _readXml(archive, navPath);
      final nav = document.findAllElements('nav').where((element) {
        return element.attributes.any(
          (attribute) =>
              attribute.name.local == 'type' &&
              attribute.value.split(RegExp(r'\s+')).contains('toc'),
        );
      }).firstOrNull;
      final list = nav?.findElements('ol').firstOrNull;
      if (list != null) {
        return _readNavList(list, Uri(path: navPath).resolve('.'));
      }
    }

    final ncxId = spine.getAttribute('toc');
    final ncxItem = ncxId == null ? null : manifest[ncxId];
    if (ncxItem == null) return const [];
    final ncxPath = packageDirectory.resolve(ncxItem.href).normalizePath().path;
    final ncx = _readXml(archive, ncxPath);
    final navMap = ncx.findAllElements('navMap').firstOrNull;
    return navMap == null
        ? const []
        : _readNcxPoints(navMap, Uri(path: ncxPath).resolve('.'));
  }

  static List<_NavigationEntry> _readNavList(XmlElement list, Uri base) {
    return list.findElements('li').map((item) {
      final link = item.findElements('a').firstOrNull;
      final span = item.findElements('span').firstOrNull;
      final href = link?.getAttribute('href') ?? '';
      final resolved = base.resolve(href).normalizePath();
      final childList = item.findElements('ol').firstOrNull;
      return _NavigationEntry(
        title:
            (link ?? span)?.innerText.trim() ?? _titleFromPath(resolved.path),
        path: resolved.path,
        fragment: resolved.fragment.isEmpty ? null : resolved.fragment,
        children: childList == null ? const [] : _readNavList(childList, base),
      );
    }).toList();
  }

  static List<_NavigationEntry> _readNcxPoints(XmlElement parent, Uri base) {
    return parent.findElements('navPoint').map((point) {
      final content = point.findElements('content').firstOrNull;
      final resolved = base
          .resolve(content?.getAttribute('src') ?? '')
          .normalizePath();
      final label = point
          .findElements('navLabel')
          .firstOrNull
          ?.findElements('text')
          .firstOrNull
          ?.innerText
          .trim();
      return _NavigationEntry(
        title: label?.isNotEmpty == true
            ? label!
            : _titleFromPath(resolved.path),
        path: resolved.path,
        fragment: resolved.fragment.isEmpty ? null : resolved.fragment,
        children: _readNcxPoints(point, base),
      );
    }).toList();
  }

  static List<TableOfContentsEntry> _toTableOfContents(
    List<_NavigationEntry> entries,
    Map<String, String> chapterIdsByPath,
  ) {
    final result = <TableOfContentsEntry>[];
    for (final entry in entries) {
      final chapterId = chapterIdsByPath[entry.path];
      if (chapterId == null) continue;
      result.add(
        TableOfContentsEntry(
          title: entry.title,
          reference: ChapterReference(
            chapterId: chapterId,
            fragment: entry.fragment,
          ),
          children: _toTableOfContents(entry.children, chapterIdsByPath),
        ),
      );
    }
    return result;
  }

  static XmlDocument _readXml(Archive archive, String path) {
    final file = archive.find(path);
    if (file == null) {
      throw InvalidEpubFailure(message: 'An EPUB resource is missing: $path');
    }
    return XmlDocument.parse(utf8.decode(file.readBytes()!));
  }

  static String _titleFromFileName(String fileName) {
    final withoutPath = fileName.replaceAll('\\', '/').split('/').last;
    final withoutExtension = withoutPath.replaceFirst(
      RegExp(r'\.epub$', caseSensitive: false),
      '',
    );
    return withoutExtension.trim().isEmpty ? 'Untitled' : withoutExtension;
  }

  static String _titleFromPath(String path) {
    final fileName = Uri.decodeComponent(path.split('/').last);
    final title = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '').trim();
    return title.isEmpty ? 'Untitled chapter' : title;
  }

  static List<XmlElement> _elementsByLocalName(XmlNode node, String name) {
    return node.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == name)
        .toList();
  }
}

final class _ManifestItem {
  const _ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    required this.properties,
  });

  final String id;
  final String href;
  final String mediaType;
  final Set<String> properties;
}

final class _NavigationEntry {
  const _NavigationEntry({
    required this.title,
    required this.path,
    required this.fragment,
    required this.children,
  });

  final String title;
  final String path;
  final String? fragment;
  final List<_NavigationEntry> children;
}
