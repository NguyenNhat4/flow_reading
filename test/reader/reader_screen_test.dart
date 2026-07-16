import 'dart:async';

import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/books/text_anchors.dart';
import 'package:flow_reading/reader/flutter_content_measurer.dart';
import 'package:flow_reading/reader/pagination_engine.dart';
import 'package:flow_reading/reader/reader_screen.dart';
import 'package:flow_reading/reader/swipeable_reader.dart';
import 'package:flow_reading/reader/table_of_contents.dart';
import 'package:flow_reading/settings/reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pagination v2 reserves render slack and keeps anchors contiguous', () {
    final previous = ReaderLayout(
      settings: ReaderSettings(
        margins: ReaderMargins(left: 0, top: 0, right: 0, bottom: 0),
      ),
      viewportWidth: 180,
      viewportHeight: 120,
      paginationVersion: 1,
    );
    final current = ReaderLayout(
      settings: ReaderSettings(
        margins: ReaderMargins(left: 0, top: 0, right: 0, bottom: 0),
      ),
      viewportWidth: 180,
      viewportHeight: 120,
    );

    expect(current.paginationVersion, 2);
    expect(current.viewportContentHeight, 120);
    expect(PaginationEngine.usableContentHeight(current), 118);
    expect(current.paginationCacheKey, isNot(previous.paginationCacheKey));

    const measurer = FlutterContentMeasurer();
    final result = const PaginationEngine().paginate(
      chapter: _overflowRegressionChapter,
      layout: current,
      measurer: measurer,
    );
    expect(result.pages, isNotEmpty);
    for (var index = 1; index < result.pages.length; index++) {
      final previousEnd = result.pages[index - 1].end;
      final currentStart = result.pages[index].start;
      if (currentStart.blockId == previousEnd.blockId) {
        expect(currentStart.startOffset, previousEnd.startOffset);
        continue;
      }
      final previousBlockIndex = _overflowRegressionChapter.blocks.indexWhere(
        (block) => block.id == previousEnd.blockId,
      );
      final currentBlockIndex = _overflowRegressionChapter.blocks.indexWhere(
        (block) => block.id == currentStart.blockId,
      );
      expect(currentBlockIndex, previousBlockIndex + 1);
      expect(
        previousEnd.startOffset,
        measurer.sourceLength(
          _overflowRegressionChapter.blocks[previousBlockIndex],
        ),
      );
      expect(currentStart.startOffset, 0);
    }
  });

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
    final initialPosition = positions.saved.last;
    expect(initialPosition.bookId, 'book-id');
    expect(initialPosition.locator.anchor.chapterId, 'chapter-1');
    expect(initialPosition.locator.anchor.blockId, 'block-1');
    expect(initialPosition.locator.anchor.startOffset, 0);
    expect(initialPosition.updatedAt.isUtc, isTrue);

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

  testWidgets('table of contents navigates by stable reference and saves it', (
    tester,
  ) async {
    final positions = _PositionRepository();
    await _pumpReader(
      tester,
      books: _BookRepository(),
      positions: positions,
      tableOfContents: _TableOfContentsRepository(
        entries: const [
          TableOfContentsEntry(
            title: 'Part one',
            reference: ChapterReference(chapterId: 'chapter-1'),
            children: [
              TableOfContentsEntry(
                title: 'Second section',
                reference: ChapterReference(
                  chapterId: 'chapter-2',
                  blockId: 'block-2',
                ),
              ),
            ],
          ),
        ],
      ),
    );

    await tester.tap(find.byTooltip('Table of contents'));
    await tester.pumpAndSettle();
    expect(find.text('Part one'), findsOneWidget);
    expect(find.text('Second section'), findsOneWidget);

    await tester.tap(find.text('Second section'));
    await tester.pumpAndSettle();

    expect(
      find.text('No account required.', findRichText: true),
      findsOneWidget,
    );
    final saved = positions.saved.last.locator.anchor;
    expect(saved.chapterId, 'chapter-2');
    expect(saved.blockId, 'block-2');
    expect(saved.startOffset, 0);
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

  testWidgets('mixed near-full pages render without bottom overflow', (
    tester,
  ) async {
    final positions = _PositionRepository();
    await _pumpReader(
      tester,
      books: _BookRepository(chapters: const [_overflowRegressionChapter]),
      positions: positions,
    );

    expect(tester.takeException(), isNull);
    final indicator = tester.widget<Text>(
      find.byKey(const ValueKey('reader-page-indicator')),
    );
    final total = int.parse(
      RegExp(r'Page 1 of (\d+)').firstMatch(indicator.data!)!.group(1)!,
    );
    final anchors = <String>{};
    for (var page = 1; page <= total; page++) {
      final anchor = positions.saved.last.locator.anchor;
      anchors.add('${anchor.blockId}:${anchor.startOffset}');
      expect(tester.takeException(), isNull);
      if (page < total) await _swipeNext(tester);
    }

    expect(anchors, hasLength(total));
    expect(find.textContaining('Page $total of $total'), findsOneWidget);
    await _swipeNext(tester);
    expect(find.textContaining('Page $total of $total'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('saves the latest logical position when app backgrounds', (
    tester,
  ) async {
    final positions = _PositionRepository();
    await _pumpReader(tester, books: _BookRepository(), positions: positions);
    await _swipeNext(tester);
    final savesBeforeBackground = positions.saved.length;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(positions.saved, hasLength(savesBeforeBackground + 1));
    final saved = positions.saved.last;
    expect(saved.bookId, 'book-id');
    expect(saved.locator.anchor.chapterId, 'chapter-2');
    expect(saved.locator.anchor.blockId, 'block-2');
    expect(saved.locator.anchor.startOffset, 0);
    expect(saved.updatedAt.isUtc, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('waits for the final position save before closing the book', (
    tester,
  ) async {
    final positions = _PositionRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ReaderScreen(
                        book: _bookSummary,
                        bookRepository: _BookRepository(),
                        positionRepository: positions,
                        settingsRepository: _SettingsRepository(),
                      ),
                    ),
                  );
                },
                child: const Text('Open book'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open book'));
    await tester.pumpAndSettle();
    final finalSave = Completer<void>();
    positions.blockNextSave = finalSave;

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(find.text('Local Book'), findsOneWidget);
    expect(finalSave.isCompleted, isFalse);

    finalSave.complete();
    await tester.pumpAndSettle();

    expect(find.text('Open book'), findsOneWidget);
    expect(find.text('Local Book'), findsNothing);
  });

  testWidgets('layout changes preserve the current logical passage', (
    tester,
  ) async {
    final positions = _PositionRepository();
    final settings = _SettingsRepository();
    final text = List.filled(500, 'preserve ').join();
    await _pumpReader(
      tester,
      books: _BookRepository(
        chapters: [
          _chapterWithText('chapter-1', 'Long chapter', 'block-1', text),
        ],
      ),
      positions: positions,
      settings: settings,
    );
    await _swipeNext(tester);
    final before = positions.saved.last.locator.anchor;
    expect(before.startOffset, greaterThan(0));

    await tester.tap(find.byTooltip('Reader layout'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('reader-font-size-slider')),
      const Offset(120, 0),
    );
    await tester.drag(
      find.byKey(const ValueKey('reader-line-height-slider')),
      const Offset(80, 0),
    );
    await tester.drag(
      find.byKey(const ValueKey('reader-horizontal-margin-slider')),
      const Offset(100, 0),
    );
    await tester.drag(
      find.byKey(const ValueKey('reader-vertical-margin-slider')),
      const Offset(100, 0),
    );
    await tester.tap(find.byKey(const ValueKey('reader-layout-apply')));
    await tester.pumpAndSettle();

    expect(settings.saved, hasLength(1));
    expect(settings.saved.single.fontSize, greaterThan(18));
    expect(settings.saved.single.lineHeight, greaterThan(1.5));
    expect(settings.saved.single.margins.left, greaterThan(24));
    expect(settings.saved.single.margins.top, greaterThan(16));
    final after = positions.saved.last.locator.anchor;
    expect(after.blockId, before.blockId);
    expect(after.startOffset, greaterThan(0));
    expect(after.startOffset, lessThanOrEqualTo(before.startOffset));
  });

  testWidgets('viewport rotation preserves the current logical passage', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final positions = _PositionRepository();
    final text = List.filled(500, 'rotate ').join();
    await _pumpReader(
      tester,
      books: _BookRepository(
        chapters: [
          _chapterWithText('chapter-1', 'Long chapter', 'block-1', text),
        ],
      ),
      positions: positions,
    );
    await _swipeNext(tester);
    final before = positions.saved.last.locator.anchor;
    expect(before.startOffset, greaterThan(0));

    tester.view.physicalSize = const Size(900, 600);
    await tester.pumpAndSettle();

    final after = positions.saved.last.locator.anchor;
    expect(after.blockId, before.blockId);
    expect(after.startOffset, greaterThan(0));
    expect(after.startOffset, lessThanOrEqualTo(before.startOffset));
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
  _SettingsRepository? settings,
  TableOfContentsRepository? tableOfContents,
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
        settingsRepository: settings ?? _SettingsRepository(),
        tableOfContentsRepository: tableOfContents,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _TableOfContentsRepository implements TableOfContentsRepository {
  const _TableOfContentsRepository({required this.entries});

  final List<TableOfContentsEntry> entries;

  @override
  Future<List<TableOfContentsEntry>> load(String bookId) async => entries;
}

final class _SettingsRepository implements ReaderSettingsRepository {
  _SettingsRepository({ReaderSettings? initial})
    : initial = initial ?? ReaderSettings.defaults;

  final ReaderSettings initial;
  final List<ReaderSettings> saved = [];

  @override
  Future<ReaderSettings> load() async => initial;

  @override
  Future<void> save(ReaderSettings settings) async {
    saved.add(settings);
  }
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
final _bookSummary = BookSummary(
  id: 'book-id',
  title: 'Local Book',
  authors: const ['Writer'],
  importedAt: _importedAt,
);

final class _PositionRepository implements ReadingPositionRepository {
  _PositionRepository({this.initial});

  final ReadingPosition? initial;
  final List<ReadingPosition> saved = [];
  Completer<void>? blockNextSave;

  @override
  Future<ReadingPosition?> load(String bookId) async => initial;

  @override
  Future<void> save(ReadingPosition position) async {
    saved.add(position);
    final blocker = blockNextSave;
    blockNextSave = null;
    await blocker?.future;
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

const _overflowRegressionChapter = Chapter(
  id: 'chapter-overflow',
  bookId: 'book-id',
  title: 'Overflow regression',
  order: 0,
  blocks: [
    HeadingBlock(
      id: 'overflow-heading',
      chapterId: 'chapter-overflow',
      order: 0,
      level: 2,
      spans: [InlineTextSpan(text: 'Measured reader layout')],
    ),
    ParagraphBlock(
      id: 'overflow-paragraph',
      chapterId: 'chapter-overflow',
      order: 1,
      spans: [
        InlineTextSpan(
          text:
              'Styled Unicode text 😀 preserves source offsets while bold and italic fragments wrap across several lines. ',
          bold: true,
        ),
        InlineTextSpan(
          text:
              'Additional paragraph content fills the available page height closely enough to exercise fractional text metrics and block spacing. ',
          italic: true,
        ),
      ],
    ),
    QuoteBlock(
      id: 'overflow-quote',
      chapterId: 'chapter-overflow',
      order: 2,
      spans: [
        InlineTextSpan(
          text:
              'Quoted content uses the shared inset and can continue onto another page without changing its stable source identity.',
        ),
      ],
    ),
    ListBlock(
      id: 'overflow-list',
      chapterId: 'chapter-overflow',
      order: 3,
      items: [
        BookListItem(
          spans: [
            InlineTextSpan(
              text: 'First list item contains enough text to wrap naturally.',
            ),
          ],
        ),
        BookListItem(
          spans: [
            InlineTextSpan(
              text: 'Second list item verifies deterministic list projection.',
            ),
          ],
        ),
      ],
    ),
    ImageBlock(
      id: 'overflow-image',
      chapterId: 'chapter-overflow',
      order: 4,
      assetId: 'overflow-asset',
      altText: 'Atomic image placeholder',
    ),
    ParagraphBlock(
      id: 'overflow-ending',
      chapterId: 'chapter-overflow',
      order: 5,
      spans: [InlineTextSpan(text: 'Content after the image remains visible.')],
    ),
  ],
);
