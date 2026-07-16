import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens canonical content and saves chapter navigation', (
    tester,
  ) async {
    final books = _BookRepository();
    final positions = _PositionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          book: BookSummary(
            id: 'book-id',
            title: 'Local Book',
            authors: ['Writer'],
            importedAt: _importedAt,
          ),
          bookRepository: books,
          positionRepository: positions,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First chapter'), findsOneWidget);
    expect(find.text('Read locally.'), findsOneWidget);
    expect(positions.saved.last.locator.anchor.blockId, 'block-1');

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Second chapter'), findsOneWidget);
    expect(find.text('No account required.'), findsOneWidget);
    expect(positions.saved.last.locator.anchor.blockId, 'block-2');
  });

  testWidgets('shows a helpful state for an empty canonical book', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScreen(
          book: BookSummary(
            id: 'book-id',
            title: 'Empty Book',
            authors: [],
            importedAt: _importedAt,
          ),
          bookRepository: _BookRepository(chapters: const []),
          positionRepository: _PositionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This book has no readable content.'), findsOneWidget);
  });
}

final _importedAt = DateTime.utc(2026);

final class _PositionRepository implements ReadingPositionRepository {
  final List<ReadingPosition> saved = [];

  @override
  Future<ReadingPosition?> load(String bookId) async => null;

  @override
  Future<void> save(ReadingPosition position) async {
    saved.add(position);
  }
}

final class _BookRepository implements BookRepository {
  _BookRepository({List<Chapter>? chapters}) : chapters = chapters ?? _chapters;

  final List<Chapter> chapters;

  @override
  Future<List<Chapter>> loadChapters(String bookId) async => chapters;

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

const _chapters = [
  Chapter(
    id: 'chapter-1',
    bookId: 'book-id',
    title: 'First chapter',
    order: 0,
    blocks: [
      ParagraphBlock(
        id: 'block-1',
        chapterId: 'chapter-1',
        order: 0,
        spans: [InlineTextSpan(text: 'Read locally.')],
      ),
    ],
  ),
  Chapter(
    id: 'chapter-2',
    bookId: 'book-id',
    title: 'Second chapter',
    order: 1,
    blocks: [
      ParagraphBlock(
        id: 'block-2',
        chapterId: 'chapter-2',
        order: 0,
        spans: [InlineTextSpan(text: 'No account required.')],
      ),
    ],
  ),
];
