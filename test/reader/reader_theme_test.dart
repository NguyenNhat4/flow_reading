import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/reader/reader_screen.dart';
import 'package:flow_reading/settings/reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reader themes use readable colors and matching system bars', (
    tester,
  ) async {
    for (final readerTheme in ReaderTheme.values) {
      await _pumpReader(
        tester,
        settings: _SettingsRepository(
          initial: ReaderSettings(theme: readerTheme),
        ),
        positions: _PositionRepository(),
      );

      final theme = tester.widget<Theme>(
        find.byKey(const ValueKey('reader-theme')),
      );
      final scheme = theme.data.colorScheme;
      expect(_contrast(scheme.surface, scheme.onSurface), greaterThan(4.5));
      expect(
        scheme.brightness,
        readerTheme == ReaderTheme.dark ? Brightness.dark : Brightness.light,
      );
      if (readerTheme == ReaderTheme.paper) {
        expect(scheme.surface, const Color(0xFFF4ECD8));
        expect(scheme.onSurface, const Color(0xFF2F261D));
      }

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byKey(const ValueKey('reader-system-ui-style')),
      );
      expect(region.value.statusBarColor, scheme.surface);
      expect(region.value.systemNavigationBarColor, scheme.surface);
      expect(
        region.value.statusBarIconBrightness,
        readerTheme == ReaderTheme.dark ? Brightness.light : Brightness.dark,
      );
    }
  });

  testWidgets('theme selection persists without repaginating', (tester) async {
    final settings = _SettingsRepository();
    final positions = _PositionRepository();
    await _pumpReader(tester, settings: settings, positions: positions);
    final savesBeforeThemeChange = positions.saved.length;

    await tester.tap(find.byTooltip('Reader layout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paper'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reader-layout-apply')));
    await tester.pumpAndSettle();

    expect(settings.current.theme, ReaderTheme.paper);
    expect(positions.saved, hasLength(savesBeforeThemeChange + 1));
    var theme = tester.widget<Theme>(
      find.byKey(const ValueKey('reader-theme')),
    );
    expect(theme.data.colorScheme.surface, const Color(0xFFF4ECD8));

    await _pumpReader(tester, settings: settings, positions: positions);
    theme = tester.widget<Theme>(find.byKey(const ValueKey('reader-theme')));
    expect(theme.data.colorScheme.surface, const Color(0xFFF4ECD8));
  });
}

Future<void> _pumpReader(
  WidgetTester tester, {
  required _SettingsRepository settings,
  required _PositionRepository positions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReaderScreen(
        key: UniqueKey(),
        book: _bookSummary,
        bookRepository: _BookRepository(),
        positionRepository: positions,
        settingsRepository: settings,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first
      : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

final _bookSummary = BookSummary(
  id: 'book-id',
  title: 'Local Book',
  authors: const ['Writer'],
  importedAt: DateTime.utc(2026),
);

final class _SettingsRepository implements ReaderSettingsRepository {
  _SettingsRepository({ReaderSettings? initial})
    : current = initial ?? ReaderSettings.defaults;

  ReaderSettings current;

  @override
  Future<ReaderSettings> load() async => current;

  @override
  Future<void> save(ReaderSettings settings) async {
    current = settings;
  }
}

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
  @override
  Future<List<Chapter>> loadChapters(String bookId) async => const [
    Chapter(
      id: 'chapter-1',
      bookId: 'book-id',
      title: 'Chapter',
      order: 0,
      blocks: [
        ParagraphBlock(
          id: 'block-1',
          chapterId: 'chapter-1',
          order: 0,
          spans: [InlineTextSpan(text: 'Readable themed text.')],
        ),
      ],
    ),
  ];

  @override
  Future<bool> containsContentHash(String contentHash) async => false;

  @override
  Future<void> delete(String bookId) async {}

  @override
  Future<List<BookSummary>> listBooks() async => const [];

  @override
  Future<BookMetadata?> readMetadata(String bookId) async => null;

  @override
  Future<void> save(Book book) async {}

  @override
  Future<void> updateDetectedLanguage(String bookId, String? language) async {}
}
