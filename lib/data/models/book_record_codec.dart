import 'package:flow_reading/domain/models/book_models.dart';

typedef BookJsonMap = Map<String, Object?>;

/// Encodes canonical books using the existing SQLite JSON compatibility shape.
final class BookRecordCodec {
  const BookRecordCodec._();

  static BookJsonMap encodeBook(Book value) => {
    'id': value.id,
    'metadata': encodeMetadata(value.metadata),
    'originalFile': value.originalFile,
    'chapters': value.chapters.map(encodeChapter).toList(),
    'tableOfContents': value.tableOfContents
        .map(encodeTableOfContents)
        .toList(),
    'assets': value.assets.map(encodeAsset).toList(),
    'detectedLanguage': value.detectedLanguage,
    'importedAt': value.importedAt.toIso8601String(),
  };

  static Book decodeBook(BookJsonMap json) => Book(
    id: json['id'] as String,
    metadata: decodeMetadata(_map(json['metadata'])),
    originalFile: json['originalFile'] as String,
    chapters: _maps(json['chapters']).map(decodeChapter).toList(),
    tableOfContents: _maps(
      json['tableOfContents'],
    ).map(decodeTableOfContents).toList(),
    assets: _maps(json['assets']).map(decodeAsset).toList(),
    detectedLanguage: json['detectedLanguage'] as String?,
    importedAt: DateTime.parse(json['importedAt'] as String),
  );

  static BookJsonMap encodeMetadata(BookMetadata value) => {
    'title': value.title,
    'authors': value.authors,
    'language': value.language,
    'identifier': value.identifier,
    'publisher': value.publisher,
    'description': value.description,
    'coverAssetId': value.coverAssetId,
  };

  static BookMetadata decodeMetadata(BookJsonMap json) => BookMetadata(
    title: json['title'] as String,
    authors: (json['authors'] as List).cast<String>(),
    language: json['language'] as String?,
    identifier: json['identifier'] as String?,
    publisher: json['publisher'] as String?,
    description: json['description'] as String?,
    coverAssetId: json['coverAssetId'] as String?,
  );

  static BookJsonMap encodeChapter(Chapter value) => {
    'id': value.id,
    'bookId': value.bookId,
    'title': value.title,
    'order': value.order,
    'blocks': value.blocks.map(_encodeBlock).toList(),
    'sourceHref': value.sourceHref,
  };

  static Chapter decodeChapter(BookJsonMap json) => Chapter(
    id: json['id'] as String,
    bookId: json['bookId'] as String,
    title: json['title'] as String,
    order: json['order'] as int,
    blocks: _maps(json['blocks']).map(_decodeBlock).toList(),
    sourceHref: json['sourceHref'] as String?,
  );

  static BookJsonMap encodeTableOfContents(TableOfContentsEntry value) => {
    'title': value.title,
    'reference': _encodeReference(value.reference),
    'children': value.children.map(encodeTableOfContents).toList(),
  };

  static TableOfContentsEntry decodeTableOfContents(BookJsonMap json) =>
      TableOfContentsEntry(
        title: json['title'] as String,
        reference: _decodeReference(_map(json['reference'])),
        children: _maps(json['children']).map(decodeTableOfContents).toList(),
      );

  static BookJsonMap encodeAsset(BookAsset value) => {
    'id': value.id,
    'bookId': value.bookId,
    'mediaType': value.mediaType,
    'localPath': value.localPath,
    'sourceHref': value.sourceHref,
  };

  static BookAsset decodeAsset(BookJsonMap json) => BookAsset(
    id: json['id'] as String,
    bookId: json['bookId'] as String,
    mediaType: json['mediaType'] as String,
    localPath: json['localPath'] as String,
    sourceHref: json['sourceHref'] as String?,
  );

  static BookJsonMap _encodeReference(ChapterReference value) => {
    'chapterId': value.chapterId,
    'blockId': value.blockId,
    'fragment': value.fragment,
  };

  static ChapterReference _decodeReference(BookJsonMap json) =>
      ChapterReference(
        chapterId: json['chapterId'] as String,
        blockId: json['blockId'] as String?,
        fragment: json['fragment'] as String?,
      );

  static BookJsonMap _encodeBlock(ContentBlock value) => switch (value) {
    QuoteBlock() => {..._baseBlock(value), 'spans': _encodeSpans(value.spans)},
    ParagraphBlock() => {
      ..._baseBlock(value),
      'spans': _encodeSpans(value.spans),
      'sentences': value.sentences.map(_encodeSentence).toList(),
    },
    HeadingBlock() => {
      ..._baseBlock(value),
      'level': value.level,
      'spans': _encodeSpans(value.spans),
    },
    ImageBlock() => {
      ..._baseBlock(value),
      'assetId': value.assetId,
      'altText': value.altText,
      'caption': value.caption,
    },
    ListBlock() => {
      ..._baseBlock(value),
      'ordered': value.ordered,
      'items': value.items.map(_encodeListItem).toList(),
    },
  };

  static ContentBlock _decodeBlock(BookJsonMap json) => switch (json['type']) {
    'quote' => QuoteBlock(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      order: json['order'] as int,
      spans: _decodeSpans(json['spans']),
    ),
    'paragraph' => ParagraphBlock(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      order: json['order'] as int,
      spans: _decodeSpans(json['spans']),
      sentences: _maps(json['sentences']).map(_decodeSentence).toList(),
    ),
    'heading' => HeadingBlock(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      order: json['order'] as int,
      level: json['level'] as int,
      spans: _decodeSpans(json['spans']),
    ),
    'image' => ImageBlock(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      order: json['order'] as int,
      assetId: json['assetId'] as String,
      altText: json['altText'] as String?,
      caption: json['caption'] as String?,
    ),
    'list' => ListBlock(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      order: json['order'] as int,
      ordered: json['ordered'] as bool,
      items: _maps(json['items']).map(_decodeListItem).toList(),
    ),
    final type => throw FormatException(
      'Unsupported content block type: $type',
    ),
  };

  static BookJsonMap _baseBlock(ContentBlock value) => {
    'id': value.id,
    'chapterId': value.chapterId,
    'order': value.order,
    'type': value.type,
  };

  static List<BookJsonMap> _encodeSpans(List<InlineTextSpan> values) =>
      values.map(_encodeSpan).toList();

  static BookJsonMap _encodeSpan(InlineTextSpan value) => {
    'text': value.text,
    'bold': value.bold,
    'italic': value.italic,
    'underline': value.underline,
    'href': value.href,
  };

  static List<InlineTextSpan> _decodeSpans(Object? value) =>
      _maps(value).map(_decodeSpan).toList();

  static InlineTextSpan _decodeSpan(BookJsonMap json) => InlineTextSpan(
    text: json['text'] as String,
    bold: json['bold'] as bool,
    italic: json['italic'] as bool,
    underline: json['underline'] as bool,
    href: json['href'] as String?,
  );

  static BookJsonMap _encodeListItem(BookListItem value) => {
    'spans': _encodeSpans(value.spans),
    'children': value.children.map(_encodeListItem).toList(),
  };

  static BookListItem _decodeListItem(BookJsonMap json) => BookListItem(
    spans: _decodeSpans(json['spans']),
    children: _maps(json['children']).map(_decodeListItem).toList(),
  );

  static BookJsonMap _encodeSentence(BookSentence value) => {
    'id': value.id,
    'blockId': value.blockId,
    'order': value.order,
    'startOffset': value.startOffset,
    'endOffset': value.endOffset,
    'text': value.text,
  };

  static BookSentence _decodeSentence(BookJsonMap json) => BookSentence(
    id: json['id'] as String,
    blockId: json['blockId'] as String,
    order: json['order'] as int,
    startOffset: json['startOffset'] as int,
    endOffset: json['endOffset'] as int,
    text: json['text'] as String,
  );

  static BookJsonMap _map(Object? value) =>
      (value as Map).cast<String, Object?>();

  static List<BookJsonMap> _maps(Object? value) =>
      (value as List).map(_map).toList();
}
