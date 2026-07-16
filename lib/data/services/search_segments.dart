import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/book_search.dart';

Iterable<SearchableSegment> searchableSegments(
  String bookId,
  Chapter chapter,
) sync* {
  final blocks = [...chapter.blocks]
    ..sort((left, right) => left.order.compareTo(right.order));
  for (final block in blocks) {
    final text = _plainText(block);
    if (text == null || text.trim().isEmpty) continue;
    yield SearchableSegment(
      segmentId: block.id,
      bookId: bookId,
      chapterId: chapter.id,
      blockId: block.id,
      plainText: text,
    );
  }
}

Iterable<IndexedSearchTerm> indexedSearchTerms(String text) sync* {
  final earliest = <String, int>{};
  var tokenStart = -1;
  final token = StringBuffer();
  var offset = 0;
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    if (_delimiter.hasMatch(character)) {
      if (tokenStart >= 0) {
        earliest.putIfAbsent(token.toString().toLowerCase(), () => tokenStart);
        token.clear();
        tokenStart = -1;
      }
    } else {
      tokenStart = tokenStart < 0 ? offset : tokenStart;
      token.write(character);
    }
    offset += character.length;
  }
  if (tokenStart >= 0) {
    earliest.putIfAbsent(token.toString().toLowerCase(), () => tokenStart);
  }
  for (final entry in earliest.entries) {
    yield IndexedSearchTerm(term: entry.key, startOffset: entry.value);
  }
}

final class IndexedSearchTerm {
  const IndexedSearchTerm({required this.term, required this.startOffset});

  final String term;
  final int startOffset;
}

final _delimiter = RegExp(
  r'''[\s.,;:!?…“”"'()[\]{}<>/\\|@#$%^&*+=~`—–-]''',
  unicode: true,
);

String? _plainText(ContentBlock block) => switch (block) {
  ParagraphBlock() => block.text,
  HeadingBlock() => block.text,
  QuoteBlock() => block.text,
  ListBlock() => block.items.map(_listItemText).join('\n'),
  ImageBlock() => null,
};

String _listItemText(BookListItem item) =>
    [item.text, ...item.children.map(_listItemText)].join('\n');
