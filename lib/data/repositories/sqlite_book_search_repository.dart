import 'package:flow_reading/data/services/app_database.dart';
import 'package:flow_reading/data/services/search_segments.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_search.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/book_search_repository.dart';

final class SqliteBookSearchRepository implements BookSearchRepository {
  SqliteBookSearchRepository(this.appDatabase);

  final AppDatabase appDatabase;

  @override
  Future<List<BookSearchResult>> search({
    required String bookId,
    required String query,
    int limit = 50,
  }) => _guard(() async {
    final terms = indexedSearchTerms(query).map((term) => term.term).toList();
    if (terms.isEmpty || limit <= 0) return const [];
    final database = await appDatabase.open();
    final joins = <String>[];
    final arguments = <Object?>[];
    for (var index = 0; index < terms.length; index++) {
      final alias = 'term_$index';
      final prefix = index == terms.length - 1;
      joins.add('''JOIN search_terms $alias
ON $alias.segment_id = segment.segment_id
AND $alias.term ${prefix ? r"LIKE ? ESCAPE '\'" : '= ?'}''');
      arguments.add(prefix ? '${_likeValue(terms[index])}%' : terms[index]);
    }
    final candidateOffset = terms.length == 1
        ? 'term_0.start_offset'
        : 'min(${[for (var index = 0; index < terms.length; index++) 'term_$index.start_offset'].join(', ')})';
    arguments
      ..add(bookId)
      ..add(limit);
    final rows = await database.rawQuery('''
SELECT segment.segment_id, segment.book_id, segment.chapter_id,
       segment.block_id, segment.plain_text,
       min($candidateOffset) AS match_offset
FROM search_segments segment
${joins.join('\n')}
WHERE segment.book_id = ?
GROUP BY segment.segment_id
ORDER BY segment.rowid
LIMIT ?''', arguments);
    return rows.map(_fromRow).toList(growable: false);
  });

  static BookSearchResult _fromRow(Map<String, Object?> row) {
    final text = row['plain_text'] as String;
    final sourceOffset = row['match_offset'] as int;
    final anchor = TextAnchor(
      bookId: row['book_id'] as String,
      chapterId: row['chapter_id'] as String,
      blockId: row['block_id'] as String,
      startOffset: sourceOffset,
      endOffset: sourceOffset,
    );
    return BookSearchResult(
      segment: SearchableSegment(
        segmentId: row['segment_id'] as String,
        bookId: anchor.bookId,
        chapterId: anchor.chapterId,
        blockId: anchor.blockId,
        plainText: text,
      ),
      excerpt: _excerpt(text, sourceOffset),
      locator: ReadingLocator(anchor: anchor),
    );
  }

  static String _likeValue(String term) => term
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  static String _excerpt(String text, int matchOffset) {
    final start = _safeBoundary(text, (matchOffset - 60).clamp(0, text.length));
    final end = _safeBoundary(text, (matchOffset + 120).clamp(0, text.length));
    final normalized = text
        .substring(start, end)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${start > 0 ? '…' : ''}$normalized${end < text.length ? '…' : ''}';
  }

  static int _safeBoundary(String text, int offset) {
    if (offset <= 0 || offset >= text.length) return offset;
    final current = text.codeUnitAt(offset);
    final previous = text.codeUnitAt(offset - 1);
    final splitsPair =
        current >= 0xDC00 &&
        current <= 0xDFFF &&
        previous >= 0xD800 &&
        previous <= 0xDBFF;
    return splitsPair ? offset - 1 : offset;
  }

  static Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const DatabaseFailure();
    }
  }
}
