import 'dart:convert';
import 'dart:typed_data';

import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/content_identifiers.dart';
import 'package:flow_reading/books/epub_package_parser.dart';
import 'package:flow_reading/books/epub_validator.dart';
import 'package:flow_reading/books/sentence_segmenter.dart';
import 'package:flow_reading/shared/app_failure.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

typedef AssetLocalPath = String Function(String assetId, String sourceHref);

final class CanonicalAsset {
  const CanonicalAsset({required this.asset, required this.bytes});

  final BookAsset asset;
  final Uint8List bytes;
}

final class CanonicalEpubContent {
  const CanonicalEpubContent({
    required this.chapters,
    required this.tableOfContents,
    required this.assets,
  });

  final List<Chapter> chapters;
  final List<TableOfContentsEntry> tableOfContents;
  final List<CanonicalAsset> assets;
}

abstract final class CanonicalHtmlConverter {
  static CanonicalEpubContent convert(
    ValidatedEpub epub,
    EpubImportDraft draft, {
    required AssetLocalPath assetLocalPath,
  }) {
    final assetsByHref = <String, CanonicalAsset>{};
    if (draft.cover != null) {
      final cover = draft.cover!;
      assetsByHref[cover.sourceHref] = CanonicalAsset(
        asset: BookAsset(
          id: cover.id,
          bookId: draft.bookId,
          mediaType: cover.mediaType,
          localPath: assetLocalPath(cover.id, cover.sourceHref),
          sourceHref: cover.sourceHref,
        ),
        bytes: cover.bytes,
      );
    }

    final fragmentBlocks = <String, String>{};
    final chapters = draft.chapters.map((chapterDraft) {
      final file = epub.archive.find(chapterDraft.sourceHref);
      if (file == null) {
        throw InvalidEpubFailure(
          message: 'A chapter resource is missing: ${chapterDraft.sourceHref}',
        );
      }
      final document = html.parse(
        utf8.decode(file.readBytes()!, allowMalformed: true),
      );
      final state = _ChapterConversion(
        epub: epub,
        draft: draft,
        chapter: chapterDraft,
        assetLocalPath: assetLocalPath,
        assetsByHref: assetsByHref,
        fragmentBlocks: fragmentBlocks,
      );
      state.convert(document.body ?? document.documentElement!);
      return Chapter(
        id: chapterDraft.id,
        bookId: draft.bookId,
        title: chapterDraft.title,
        order: chapterDraft.order,
        blocks: List.unmodifiable(state.blocks),
        sourceHref: chapterDraft.sourceHref,
      );
    }).toList();

    return CanonicalEpubContent(
      chapters: List.unmodifiable(chapters),
      tableOfContents: List.unmodifiable(
        _resolveTableOfContents(draft.tableOfContents, fragmentBlocks),
      ),
      assets: List.unmodifiable(assetsByHref.values),
    );
  }

  static List<TableOfContentsEntry> _resolveTableOfContents(
    List<TableOfContentsEntry> entries,
    Map<String, String> fragmentBlocks,
  ) {
    return entries.map((entry) {
      final reference = entry.reference;
      final fragment = reference.fragment;
      return TableOfContentsEntry(
        title: entry.title,
        reference: ChapterReference(
          chapterId: reference.chapterId,
          blockId: fragment == null
              ? reference.blockId
              : fragmentBlocks['${reference.chapterId}#$fragment'],
          fragment: fragment,
        ),
        children: _resolveTableOfContents(entry.children, fragmentBlocks),
      );
    }).toList();
  }
}

final class _ChapterConversion {
  _ChapterConversion({
    required this.epub,
    required this.draft,
    required this.chapter,
    required this.assetLocalPath,
    required this.assetsByHref,
    required this.fragmentBlocks,
  });

  static const _ignoredElements = {
    'script',
    'style',
    'form',
    'object',
    'embed',
    'iframe',
    'canvas',
  };

  final ValidatedEpub epub;
  final EpubImportDraft draft;
  final EpubChapterDraft chapter;
  final AssetLocalPath assetLocalPath;
  final Map<String, CanonicalAsset> assetsByHref;
  final Map<String, String> fragmentBlocks;
  final List<ContentBlock> blocks = [];

  void convert(Element root) {
    for (var index = 0; index < root.nodes.length; index++) {
      _visit(root.nodes[index], 'body/$index');
    }
  }

  void _visit(Node node, String locator) {
    if (node is Text) {
      final text = _collapseWhitespace(node.data);
      if (text.trim().isNotEmpty) {
        _addParagraph([InlineTextSpan(text: text)], locator);
      }
      return;
    }
    if (node is! Element || _ignoredElements.contains(node.localName)) return;

    final name = node.localName ?? '';
    if (RegExp(r'^h[1-6]$').hasMatch(name)) {
      final spans = _spans(node);
      if (spans.isNotEmpty) {
        _add(
          HeadingBlock(
            id: _blockId('heading', locator),
            chapterId: chapter.id,
            order: blocks.length,
            level: int.parse(name.substring(1)),
            spans: spans,
          ),
          node,
        );
      }
      return;
    }
    if (name == 'p') {
      _addParagraph(_spans(node), locator, element: node);
      return;
    }
    if (name == 'blockquote') {
      final spans = _spans(node);
      if (spans.isNotEmpty) {
        _add(
          QuoteBlock(
            id: _blockId('quote', locator),
            chapterId: chapter.id,
            order: blocks.length,
            spans: spans,
          ),
          node,
        );
      }
      return;
    }
    if (name == 'ul' || name == 'ol') {
      final items = node.children
          .where((element) => element.localName == 'li')
          .map(_listItem)
          .toList();
      if (items.isNotEmpty) {
        _add(
          ListBlock(
            id: _blockId('list', locator),
            chapterId: chapter.id,
            order: blocks.length,
            items: items,
            ordered: name == 'ol',
          ),
          node,
        );
      }
      return;
    }
    if (name == 'img') {
      _addImage(node, locator);
      return;
    }

    for (var index = 0; index < node.nodes.length; index++) {
      _visit(node.nodes[index], '$locator/$index');
    }
  }

  BookListItem _listItem(Element item) {
    final inlineContainer = Element.tag('span');
    for (final node in item.nodes) {
      if (node is Element &&
          (node.localName == 'ul' || node.localName == 'ol')) {
        continue;
      }
      inlineContainer.append(node.clone(true));
    }
    final children = item.children
        .where(
          (element) => element.localName == 'ul' || element.localName == 'ol',
        )
        .expand(
          (list) => list.children
              .where((element) => element.localName == 'li')
              .map(_listItem),
        )
        .toList();
    return BookListItem(spans: _spans(inlineContainer), children: children);
  }

  void _addParagraph(
    List<InlineTextSpan> spans,
    String locator, {
    Element? element,
  }) {
    if (spans.isEmpty) return;
    final blockId = _blockId('paragraph', locator);
    final text = spans.map((span) => span.text).join();
    _add(
      ParagraphBlock(
        id: blockId,
        chapterId: chapter.id,
        order: blocks.length,
        spans: spans,
        sentences: SentenceSegmenter.segment(blockId: blockId, text: text),
      ),
      element,
    );
  }

  void _addImage(Element element, String locator) {
    final source = element.attributes['src'];
    if (source == null || source.isEmpty) return;
    final chapterBase = Uri(path: chapter.sourceHref).resolve('.');
    final sourceHref = chapterBase.resolve(source).normalizePath().path;
    final file = epub.archive.find(sourceHref);
    if (file == null) {
      throw InvalidEpubFailure(
        message: 'An EPUB image is missing: $sourceHref',
      );
    }
    final assetId = ContentIdentifiers.asset(
      bookId: draft.bookId,
      sourceHref: sourceHref,
    );
    final mediaType = _mediaType(sourceHref);
    assetsByHref.putIfAbsent(
      sourceHref,
      () => CanonicalAsset(
        asset: BookAsset(
          id: assetId,
          bookId: draft.bookId,
          mediaType: mediaType,
          localPath: assetLocalPath(assetId, sourceHref),
          sourceHref: sourceHref,
        ),
        bytes: file.readBytes()!,
      ),
    );
    _add(
      ImageBlock(
        id: _blockId('image', locator),
        chapterId: chapter.id,
        order: blocks.length,
        assetId: assetId,
        altText: element.attributes['alt'],
      ),
      element,
    );
  }

  void _add(ContentBlock block, Element? element) {
    blocks.add(block);
    final fragment = element?.id;
    if (fragment != null && fragment.isNotEmpty) {
      fragmentBlocks['${chapter.id}#$fragment'] = block.id;
    }
  }

  String _blockId(String type, String locator) => ContentIdentifiers.block(
    chapterId: chapter.id,
    order: blocks.length,
    type: type,
    sourceLocator: locator,
  );

  static List<InlineTextSpan> _spans(Element element) {
    final spans = <InlineTextSpan>[];
    void visit(
      Node node, {
      bool bold = false,
      bool italic = false,
      bool underline = false,
      String? href,
    }) {
      if (node is Text) {
        final value = _collapseWhitespace(node.data);
        if (value.isNotEmpty) {
          spans.add(
            InlineTextSpan(
              text: value,
              bold: bold,
              italic: italic,
              underline: underline,
              href: href,
            ),
          );
        }
        return;
      }
      if (node is! Element || _ignoredElements.contains(node.localName)) return;
      if (node.localName == 'br') {
        spans.add(
          InlineTextSpan(
            text: '\n',
            bold: bold,
            italic: italic,
            underline: underline,
            href: href,
          ),
        );
        return;
      }
      final name = node.localName;
      for (final child in node.nodes) {
        visit(
          child,
          bold: bold || name == 'b' || name == 'strong',
          italic: italic || name == 'i' || name == 'em',
          underline: underline || name == 'u',
          href: name == 'a' ? node.attributes['href'] : href,
        );
      }
    }

    visit(element);
    return _mergeAdjacent(spans);
  }

  static List<InlineTextSpan> _mergeAdjacent(List<InlineTextSpan> spans) {
    final merged = <InlineTextSpan>[];
    for (final span in spans) {
      if (merged.isNotEmpty) {
        final previous = merged.last;
        if (previous.bold == span.bold &&
            previous.italic == span.italic &&
            previous.underline == span.underline &&
            previous.href == span.href) {
          merged[merged.length - 1] = InlineTextSpan(
            text: previous.text + span.text,
            bold: span.bold,
            italic: span.italic,
            underline: span.underline,
            href: span.href,
          );
          continue;
        }
      }
      merged.add(span);
    }
    return merged;
  }

  static String _collapseWhitespace(String value) {
    return value.replaceAll(RegExp(r'[\t\n\r ]+'), ' ');
  }

  static String _mediaType(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      _ => 'application/octet-stream',
    };
  }
}
