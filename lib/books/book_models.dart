typedef JsonMap = Map<String, Object?>;

class Book {
  const Book({
    required this.id,
    required this.metadata,
    required this.originalFile,
    required this.chapters,
    required this.tableOfContents,
    required this.assets,
    required this.importedAt,
    this.detectedLanguage,
  });

  final String id;
  final BookMetadata metadata;
  final String originalFile;
  final List<Chapter> chapters;
  final List<TableOfContentsEntry> tableOfContents;
  final List<BookAsset> assets;
  final String? detectedLanguage;
  final DateTime importedAt;

  JsonMap toJson() => {
    'id': id,
    'metadata': metadata.toJson(),
    'originalFile': originalFile,
    'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
    'tableOfContents': tableOfContents.map((entry) => entry.toJson()).toList(),
    'assets': assets.map((asset) => asset.toJson()).toList(),
    'detectedLanguage': detectedLanguage,
    'importedAt': importedAt.toIso8601String(),
  };

  factory Book.fromJson(JsonMap json) => Book(
    id: json['id'] as String,
    metadata: BookMetadata.fromJson(_map(json['metadata'])),
    originalFile: json['originalFile'] as String,
    chapters: _maps(json['chapters']).map(Chapter.fromJson).toList(),
    tableOfContents: _maps(
      json['tableOfContents'],
    ).map(TableOfContentsEntry.fromJson).toList(),
    assets: _maps(json['assets']).map(BookAsset.fromJson).toList(),
    detectedLanguage: json['detectedLanguage'] as String?,
    importedAt: DateTime.parse(json['importedAt'] as String),
  );
}

class BookMetadata {
  const BookMetadata({
    required this.title,
    this.authors = const [],
    this.language,
    this.identifier,
    this.publisher,
    this.description,
    this.coverAssetId,
  });

  final String title;
  final List<String> authors;
  final String? language;
  final String? identifier;
  final String? publisher;
  final String? description;
  final String? coverAssetId;

  JsonMap toJson() => {
    'title': title,
    'authors': authors,
    'language': language,
    'identifier': identifier,
    'publisher': publisher,
    'description': description,
    'coverAssetId': coverAssetId,
  };

  factory BookMetadata.fromJson(JsonMap json) => BookMetadata(
    title: json['title'] as String,
    authors: _strings(json['authors']),
    language: json['language'] as String?,
    identifier: json['identifier'] as String?,
    publisher: json['publisher'] as String?,
    description: json['description'] as String?,
    coverAssetId: json['coverAssetId'] as String?,
  );
}

class Chapter {
  const Chapter({
    required this.id,
    required this.bookId,
    required this.title,
    required this.order,
    required this.blocks,
    this.sourceHref,
  });

  final String id;
  final String bookId;
  final String title;
  final int order;
  final List<ContentBlock> blocks;
  final String? sourceHref;

  JsonMap toJson() => {
    'id': id,
    'bookId': bookId,
    'title': title,
    'order': order,
    'blocks': blocks.map((block) => block.toJson()).toList(),
    'sourceHref': sourceHref,
  };

  factory Chapter.fromJson(JsonMap json) => Chapter(
    id: json['id'] as String,
    bookId: json['bookId'] as String,
    title: json['title'] as String,
    order: json['order'] as int,
    blocks: _maps(json['blocks']).map(ContentBlock.fromJson).toList(),
    sourceHref: json['sourceHref'] as String?,
  );
}

class ChapterReference {
  const ChapterReference({
    required this.chapterId,
    this.blockId,
    this.fragment,
  });

  final String chapterId;
  final String? blockId;
  final String? fragment;

  JsonMap toJson() => {
    'chapterId': chapterId,
    'blockId': blockId,
    'fragment': fragment,
  };

  factory ChapterReference.fromJson(JsonMap json) => ChapterReference(
    chapterId: json['chapterId'] as String,
    blockId: json['blockId'] as String?,
    fragment: json['fragment'] as String?,
  );
}

sealed class ContentBlock {
  const ContentBlock({
    required this.id,
    required this.chapterId,
    required this.order,
  });

  final String id;
  final String chapterId;
  final int order;
  String get type;

  JsonMap toJson();

  static JsonMap baseJson(ContentBlock block) => {
    'id': block.id,
    'chapterId': block.chapterId,
    'order': block.order,
    'type': block.type,
  };

  factory ContentBlock.fromJson(JsonMap json) {
    return switch (json['type']) {
      'paragraph' => ParagraphBlock.fromJson(json),
      'heading' => HeadingBlock.fromJson(json),
      'image' => ImageBlock.fromJson(json),
      'list' => ListBlock.fromJson(json),
      'quote' => QuoteBlock.fromJson(json),
      final type => throw FormatException(
        'Unsupported content block type: $type',
      ),
    };
  }
}

class QuoteBlock extends ContentBlock {
  const QuoteBlock({
    required super.id,
    required super.chapterId,
    required super.order,
    required this.spans,
  });

  final List<InlineTextSpan> spans;

  String get text => spans.map((span) => span.text).join();

  @override
  String get type => 'quote';

  @override
  JsonMap toJson() => {
    ...ContentBlock.baseJson(this),
    'spans': spans.map((span) => span.toJson()).toList(),
  };

  factory QuoteBlock.fromJson(JsonMap json) => QuoteBlock(
    id: json['id'] as String,
    chapterId: json['chapterId'] as String,
    order: json['order'] as int,
    spans: _maps(json['spans']).map(InlineTextSpan.fromJson).toList(),
  );
}

class ParagraphBlock extends ContentBlock {
  const ParagraphBlock({
    required super.id,
    required super.chapterId,
    required super.order,
    required this.spans,
    this.sentences = const [],
  });

  final List<InlineTextSpan> spans;
  final List<BookSentence> sentences;

  String get text => spans.map((span) => span.text).join();

  @override
  String get type => 'paragraph';

  @override
  JsonMap toJson() => {
    ...ContentBlock.baseJson(this),
    'spans': spans.map((span) => span.toJson()).toList(),
    'sentences': sentences.map((sentence) => sentence.toJson()).toList(),
  };

  factory ParagraphBlock.fromJson(JsonMap json) => ParagraphBlock(
    id: json['id'] as String,
    chapterId: json['chapterId'] as String,
    order: json['order'] as int,
    spans: _maps(json['spans']).map(InlineTextSpan.fromJson).toList(),
    sentences: _maps(json['sentences']).map(BookSentence.fromJson).toList(),
  );
}

class HeadingBlock extends ContentBlock {
  const HeadingBlock({
    required super.id,
    required super.chapterId,
    required super.order,
    required this.level,
    required this.spans,
  }) : assert(level >= 1 && level <= 6);

  final int level;
  final List<InlineTextSpan> spans;

  String get text => spans.map((span) => span.text).join();

  @override
  String get type => 'heading';

  @override
  JsonMap toJson() => {
    ...ContentBlock.baseJson(this),
    'level': level,
    'spans': spans.map((span) => span.toJson()).toList(),
  };

  factory HeadingBlock.fromJson(JsonMap json) => HeadingBlock(
    id: json['id'] as String,
    chapterId: json['chapterId'] as String,
    order: json['order'] as int,
    level: json['level'] as int,
    spans: _maps(json['spans']).map(InlineTextSpan.fromJson).toList(),
  );
}

class ImageBlock extends ContentBlock {
  const ImageBlock({
    required super.id,
    required super.chapterId,
    required super.order,
    required this.assetId,
    this.altText,
    this.caption,
  });

  final String assetId;
  final String? altText;
  final String? caption;

  @override
  String get type => 'image';

  @override
  JsonMap toJson() => {
    ...ContentBlock.baseJson(this),
    'assetId': assetId,
    'altText': altText,
    'caption': caption,
  };

  factory ImageBlock.fromJson(JsonMap json) => ImageBlock(
    id: json['id'] as String,
    chapterId: json['chapterId'] as String,
    order: json['order'] as int,
    assetId: json['assetId'] as String,
    altText: json['altText'] as String?,
    caption: json['caption'] as String?,
  );
}

class ListBlock extends ContentBlock {
  const ListBlock({
    required super.id,
    required super.chapterId,
    required super.order,
    required this.items,
    this.ordered = false,
  });

  final bool ordered;
  final List<BookListItem> items;

  @override
  String get type => 'list';

  @override
  JsonMap toJson() => {
    ...ContentBlock.baseJson(this),
    'ordered': ordered,
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory ListBlock.fromJson(JsonMap json) => ListBlock(
    id: json['id'] as String,
    chapterId: json['chapterId'] as String,
    order: json['order'] as int,
    ordered: json['ordered'] as bool,
    items: _maps(json['items']).map(BookListItem.fromJson).toList(),
  );
}

class InlineTextSpan {
  const InlineTextSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.href,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? href;

  JsonMap toJson() => {
    'text': text,
    'bold': bold,
    'italic': italic,
    'underline': underline,
    'href': href,
  };

  factory InlineTextSpan.fromJson(JsonMap json) => InlineTextSpan(
    text: json['text'] as String,
    bold: json['bold'] as bool,
    italic: json['italic'] as bool,
    underline: json['underline'] as bool,
    href: json['href'] as String?,
  );
}

class BookListItem {
  const BookListItem({required this.spans, this.children = const []});

  final List<InlineTextSpan> spans;
  final List<BookListItem> children;

  String get text => spans.map((span) => span.text).join();

  JsonMap toJson() => {
    'spans': spans.map((span) => span.toJson()).toList(),
    'children': children.map((item) => item.toJson()).toList(),
  };

  factory BookListItem.fromJson(JsonMap json) => BookListItem(
    spans: _maps(json['spans']).map(InlineTextSpan.fromJson).toList(),
    children: _maps(json['children']).map(BookListItem.fromJson).toList(),
  );
}

class BookSentence {
  const BookSentence({
    required this.id,
    required this.blockId,
    required this.order,
    required this.startOffset,
    required this.endOffset,
    required this.text,
  }) : assert(startOffset >= 0),
       assert(endOffset >= startOffset);

  final String id;
  final String blockId;
  final int order;
  final int startOffset;
  final int endOffset;
  final String text;

  JsonMap toJson() => {
    'id': id,
    'blockId': blockId,
    'order': order,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'text': text,
  };

  factory BookSentence.fromJson(JsonMap json) => BookSentence(
    id: json['id'] as String,
    blockId: json['blockId'] as String,
    order: json['order'] as int,
    startOffset: json['startOffset'] as int,
    endOffset: json['endOffset'] as int,
    text: json['text'] as String,
  );
}

class BookAsset {
  const BookAsset({
    required this.id,
    required this.bookId,
    required this.mediaType,
    required this.localPath,
    this.sourceHref,
  });

  final String id;
  final String bookId;
  final String mediaType;
  final String localPath;
  final String? sourceHref;

  JsonMap toJson() => {
    'id': id,
    'bookId': bookId,
    'mediaType': mediaType,
    'localPath': localPath,
    'sourceHref': sourceHref,
  };

  factory BookAsset.fromJson(JsonMap json) => BookAsset(
    id: json['id'] as String,
    bookId: json['bookId'] as String,
    mediaType: json['mediaType'] as String,
    localPath: json['localPath'] as String,
    sourceHref: json['sourceHref'] as String?,
  );
}

class TableOfContentsEntry {
  const TableOfContentsEntry({
    required this.title,
    required this.reference,
    this.children = const [],
  });

  final String title;
  final ChapterReference reference;
  final List<TableOfContentsEntry> children;

  JsonMap toJson() => {
    'title': title,
    'reference': reference.toJson(),
    'children': children.map((entry) => entry.toJson()).toList(),
  };

  factory TableOfContentsEntry.fromJson(JsonMap json) => TableOfContentsEntry(
    title: json['title'] as String,
    reference: ChapterReference.fromJson(_map(json['reference'])),
    children: _maps(
      json['children'],
    ).map(TableOfContentsEntry.fromJson).toList(),
  );
}

JsonMap _map(Object? value) => (value as Map).cast<String, Object?>();

List<JsonMap> _maps(Object? value) =>
    (value as List).map((item) => _map(item)).toList();

List<String> _strings(Object? value) => (value as List).cast<String>();
