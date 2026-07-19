import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';

/// Resolves stable reader anchors against canonical chapter content.
final class ReaderContentIndex {
  ReaderContentIndex(List<Chapter> chapters)
    : _chapters = List.unmodifiable(chapters),
      _chaptersById = Map.unmodifiable({
        for (final chapter in chapters) chapter.id: chapter,
      });

  final List<Chapter> _chapters;
  final Map<String, Chapter> _chaptersById;

  TextAnchor? collapsedAnchor(String bookId, TextAnchor anchor) {
    if (anchor.bookId != bookId) return null;
    final chapter = _chaptersById[anchor.chapterId];
    if (chapter == null) return null;
    final block = chapter.blocks
        .where((candidate) => candidate.id == anchor.blockId)
        .firstOrNull;
    if (block == null) return null;
    final extent = canonicalText(block).length;
    if (anchor.startOffset < 0 ||
        anchor.endOffset < anchor.startOffset ||
        anchor.endOffset > extent) {
      return null;
    }
    return TextAnchor(
      bookId: anchor.bookId,
      chapterId: anchor.chapterId,
      blockId: anchor.blockId,
      startOffset: anchor.startOffset,
      endOffset: anchor.startOffset,
    );
  }

  TextAnchor? anchorForReference(String bookId, ChapterReference reference) {
    final chapter = _chaptersById[reference.chapterId];
    if (chapter == null) return null;
    final blocks = [...chapter.blocks]
      ..sort((left, right) => left.order.compareTo(right.order));
    if (blocks.isEmpty) return null;
    final requestedBlockId = reference.blockId;
    final block = requestedBlockId == null
        ? blocks.first
        : blocks
              .where((candidate) => candidate.id == requestedBlockId)
              .firstOrNull;
    if (block == null) return null;
    return TextAnchor(
      bookId: bookId,
      chapterId: chapter.id,
      blockId: block.id,
      startOffset: 0,
      endOffset: 0,
    );
  }

  String chapterTitle(TextAnchor anchor) =>
      _chaptersById[anchor.chapterId]?.title ?? 'Unknown chapter';

  String passagePreview(TextAnchor anchor) {
    final block = _chapters
        .expand((chapter) => chapter.blocks)
        .where((candidate) => candidate.id == anchor.blockId)
        .firstOrNull;
    if (block == null) return 'Passage unavailable';
    final text = canonicalText(block);
    if (text.isEmpty) return 'Passage unavailable';
    final start = anchor.startOffset.clamp(0, text.length);
    final end = anchor.endOffset.clamp(start, text.length);
    final previewStart = start == end
        ? (start - 40).clamp(0, text.length)
        : start;
    final previewEnd = start == end ? (start + 80).clamp(0, text.length) : end;
    final preview = text
        .substring(previewStart, previewEnd)
        .replaceAll(RegExp(r'\s+'), ' ');
    if (preview.isEmpty) return 'Passage unavailable';
    return preview.length <= 120 ? preview : '${preview.substring(0, 117)}…';
  }

  static String canonicalText(ContentBlock block) => switch (block) {
    ParagraphBlock() => block.text,
    HeadingBlock() => block.text,
    QuoteBlock() => block.text,
    ListBlock() => block.items.map(_listItemText).join('\n'),
    ImageBlock() => '\uFFFC',
  };
}

String _listItemText(BookListItem item) =>
    [item.text, ...item.children.map(_listItemText)].join('\n');
