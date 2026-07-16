import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/books/text_anchors.dart';
import 'package:flow_reading/reader/reader_screen.dart';
import 'package:flow_reading/reader/swipeable_reader.dart';
import 'package:flow_reading/settings/reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('swipes through spine chapters and respects book bounds', (
    tester,
  ) async {
    final positions = _PositionRepository();
    await _pumpReader(
      tester,
      books: _BookRepository(chapters: _chapters.reversed.toList()),
      positions: positions,
    );

    expect(find.text('Read locally.', findRichText: true), findsOneWidget);
    expect(find.text('First chapter · Page 1 of 2'), findsOneWidget);
    expect(positions.saved.last.locator.anchor.blockId, 'block-1');

    await _swipePrevious(tester);
    expect(find.text('First chapter · Page 1 of 2'), findsOneWidget);

    await _swipeNext(tester);
    expect(
      find.text('No account required.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Second chapter · Page 2 of 2'), findsOneWidget);
    expect(positions.saved.last.locator.anchor.blockId, 'block-2');

    await _swipeNext(tester);
    expect(find.text('Second chapter · Page 2 of 2'), findsOneWidget);

    await _swipePrevious(tester);
    expect(find.text('Read locally.', findRichText: true), findsOneWidget);
    expect(find.text('First chapter · Page 1 of 2'), findsOneWidget);
  });

  testWidgets('long content advances by stable offsets within a chapter', (
    tester,
  ) async {
    final positions = _PositionRepository();
    final text = List.filled(300, 'read ').join();
    await _pumpReader(
      tester,
      books: _BookRepository(
        chapters: [
          _chapterWithText('chapter-1', 'Long chapter', 'block-1', text),
        ],
      ),
      positions: positions,
    );

    expect(find.textContaining('Page 1 of '), findsOneWidget);
    final firstOffset = positions.saved.last.locator.anchor.startOffset;
    await _swipeNext(tester);

    expect(
      positions.saved.last.locator.anchor.startOffset,
      greaterThan(firstOffset),
    );
    expect(positions.saved.last.locator.anchor.blockId, 'block-1');
  });

  testWidgets('every long-text page renders without vertical overflow', (
    tester,
  ) async {
    final text = List.filled(
      180,
      'Longer sentence content exercises realistic wrapping. ',
    ).join();
    await _pumpReader(
      tester,
      books: _BookRepository(
        chapters: [
          _chapterWithText('chapter-1', 'Long chapter', 'block-1', text),
        ],
      ),
      positions: _PositionRepository(),
    );

    final indicator = tester.widget<Text>(
      find.byKey(const ValueKey('reader-page-indicator')),
    );
    final total = int.parse(
      RegExp(r'Page 1 of (\d+)').firstMatch(indicator.data!)!.group(1)!,
    );
    for (var page = 1; page < total; page++) {
      await _swipeNext(tester);
    }
    expect(find.textContaining('Page $total of $total'), findsOneWidget);
  });

  testWidgets('restores a saved locator to its containing page', (
    tester,
  ) async {
    final text = List.filled(300, 'restore ').join();
    final saved = ReadingPosition(
      bookId: 'book-id',
      locator: ReadingLocator(
        anchor: TextAnchor(
          bookId: 'book-id',
          chapterId: 'chapter-1',
          blockId: 'block-1',
          startOffset: 700,
          endOffset: 700,
        ),
      ),
      updatedAt: DateTime.utc(2026),
    );
    final positions = _PositionRepository(initial: saved);
    await _pumpReader(
      tester,
      books: _BookRepository(
        chapters: [
          _chapterWithText('chapter-1', 'Long chapter', 'block-1', text),
        ],
      ),
      positions: positions,
    );

    final restored = positions.saved.last.locator.anchor;
    expect(restored.startOffset, greaterThan(0));
    expect(restored.startOffset, lessThanOrEqualTo(700));
    expect(find.textContaining('Page 1 of '), findsNothing);
  });

  testWidgets('renders mixed canonical fragments inside paginated pages', (
    tester,
  ) async {
    await _pumpReader(
      tester,
      books: _BookRepository(chapters: [_mixedChapter]),
      positions: _PositionRepository(),
    );

    expect(find.text('Heading', findRichText: true), findsOneWidget);
    expect(find.text('Styled passage', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('Quoted text', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('• List item', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('shows safe states for empty and failed content', (tester) async {
    await _pumpReader(
      tester,
      books: _BookRepository(chapters: const []),
      positions: _PositionRepository(),
    );
    expect(find.text('This book has no readable content.'), findsOneWidget);

    await _pumpReader(
      tester,
      books: _BookRepository(loadError: StateError('failed')),
      positions: _PositionRepository(),
    );
    expect(find.text('The book could not be opened.'), findsOneWidget);
  });

  testWidgets('shows a safe pagination error for an unusable viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 40,
            height: 80,
            child: SwipeableReader(
              chapters: _chapters,
              settings: ReaderSettings.defaults,
              onPositionChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This book could not be paginated.'), findsOneWidget);
  });
}

Future<void> _pumpReader(
  WidgetTester tester, {
  required _BookRepository books,
  required _PositionRepository positions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReaderScreen(
        key: UniqueKey(),
        book: BookSummary(
          id: 'book-id',
          title: 'Local Book',
          authors: const ['Writer'],
          importedAt: _importedAt,
        ),
        bookRepository: books,
        positionRepository: positions,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _swipeNext(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('reader-page-view')),
    const Offset(-600, 0),
  );
  await tester.pumpAndSettle();
}

Future<void> _swipePrevious(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('reader-page-view')),
    const Offset(600, 0),
  );
  await tester.pumpAndSettle();
}

final _importedAt = DateTime.utc(2026);

final class _PositionRepository implements ReadingPositionRepository {
  _PositionRepository({this.initial});

  final ReadingPosition? initial;
  final List<ReadingPosition> saved = [];

  @override
  Future<ReadingPosition?> load(String bookId) async => initial;

  @override
  Future<void> save(ReadingPosition position) async {
    saved.add(position);
  }
}

final class _BookRepository implements BookRepository {
  _BookRepository({List<Chapter>? chapters, this.loadError})
    : chapters = chapters ?? _chapters;

  final List<Chapter> chapters;
  final Object? loadError;

  @override
  Future<List<Chapter>> loadChapters(String bookId) async {
    final error = loadError;
    if (error != null) throw error;
    return chapters;
  }

  @override
  Future<List<BookSummary>> listBooks() async => const [];

  @override
  Future<BookMetadata?> readMetadata(String bookId) async => null;

  @override
  Future<bool> containsContentHash(String contentHash) async => false;

  @override
  Future<void> delete(String bookId) async {}

  @override
  Future<void> save(Book book) async {}

  @override
  Future<void> updateDetectedLanguage(String bookId, String? language) async {}
}

final _chapters = [
  _chapterWithText('chapter-1', 'First chapter', 'block-1', 'Read locally.'),
  _chapterWithText(
    'chapter-2',
    'Second chapter',
    'block-2',
    'No account required.',
    order: 1,
  ),
];

Chapter _chapterWithText(
  String chapterId,
  String title,
  String blockId,
  String text, {
  int order = 0,
}) => Chapter(
  id: chapterId,
  bookId: 'book-id',
  title: title,
  order: order,
  blocks: [
    ParagraphBlock(
      id: blockId,
      chapterId: chapterId,
      order: 0,
      spans: [InlineTextSpan(text: text)],
    ),
  ],
);

const _mixedChapter = Chapter(
  id: 'chapter-mixed',
  bookId: 'book-id',
  title: 'Mixed chapter',
  order: 0,
  blocks: [
    HeadingBlock(
      id: 'heading',
      chapterId: 'chapter-mixed',
      order: 0,
      level: 2,
      spans: [InlineTextSpan(text: 'Heading')],
    ),
    ParagraphBlock(
      id: 'paragraph',
      chapterId: 'chapter-mixed',
      order: 1,
      spans: [InlineTextSpan(text: 'Styled passage', bold: true)],
    ),
    QuoteBlock(
      id: 'quote',
      chapterId: 'chapter-mixed',
      order: 2,
      spans: [InlineTextSpan(text: 'Quoted text')],
    ),
    ListBlock(
      id: 'list',
      chapterId: 'chapter-mixed',
      order: 3,
      items: [
        BookListItem(spans: [InlineTextSpan(text: 'List item')]),
      ],
    ),
  ],
);
