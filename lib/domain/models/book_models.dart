final class Book {
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
}

final class BookMetadata {
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
}

final class Chapter {
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
}

final class ChapterReference {
  const ChapterReference({
    required this.chapterId,
    this.blockId,
    this.fragment,
  });

  final String chapterId;
  final String? blockId;
  final String? fragment;
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
}

final class QuoteBlock extends ContentBlock {
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
}

final class ParagraphBlock extends ContentBlock {
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
}

final class HeadingBlock extends ContentBlock {
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
}

final class ImageBlock extends ContentBlock {
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
}

final class ListBlock extends ContentBlock {
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
}

final class InlineTextSpan {
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
}

final class BookListItem {
  const BookListItem({required this.spans, this.children = const []});

  final List<InlineTextSpan> spans;
  final List<BookListItem> children;
  String get text => spans.map((span) => span.text).join();
}

final class BookSentence {
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
}

final class BookAsset {
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
}

final class TableOfContentsEntry {
  const TableOfContentsEntry({
    required this.title,
    required this.reference,
    this.children = const [],
  });

  final String title;
  final ChapterReference reference;
  final List<TableOfContentsEntry> children;
}
