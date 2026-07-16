import 'dart:async';

import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/books/text_anchors.dart';
import 'package:flow_reading/reader/reader_layout_controls.dart';
import 'package:flow_reading/reader/swipeable_reader.dart';
import 'package:flow_reading/reader/table_of_contents.dart';
import 'package:flow_reading/settings/reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class ReadingPosition {
  const ReadingPosition({
    required this.bookId,
    required this.locator,
    required this.updatedAt,
  });

  final String bookId;
  final ReadingLocator locator;
  final DateTime updatedAt;
}

abstract interface class ReadingPositionRepository {
  Future<ReadingPosition?> load(String bookId);

  Future<void> save(ReadingPosition position);
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    required this.book,
    required this.bookRepository,
    required this.positionRepository,
    required this.settingsRepository,
    this.tableOfContentsRepository,
    super.key,
  });

  final BookSummary book;
  final BookRepository bookRepository;
  final ReadingPositionRepository positionRepository;
  final ReaderSettingsRepository settingsRepository;
  final TableOfContentsRepository? tableOfContentsRepository;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  late final Future<List<Chapter>> _loading = _load();
  Future<void> _saveTail = Future<void>.value();
  ReadingLocator? _locator;
  ReaderSettings _settings = ReaderSettings.defaults;
  List<Chapter> _chapters = const [];
  List<TableOfContentsEntry> _tableOfContents = const [];
  int _readerGeneration = 0;
  bool _allowPop = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<List<Chapter>> _load() async {
    final results = await Future.wait<Object?>([
      widget.bookRepository.loadChapters(widget.book.id),
      widget.positionRepository.load(widget.book.id),
      widget.settingsRepository.load(),
      widget.tableOfContentsRepository?.load(widget.book.id) ??
          Future<List<TableOfContentsEntry>>.value(const []),
    ]);
    final chapters = results[0]! as List<Chapter>;
    final saved = results[1] as ReadingPosition?;
    _locator = saved?.locator;
    final settings = results[2]! as ReaderSettings;
    final tableOfContents = results[3]! as List<TableOfContentsEntry>;
    if (mounted) {
      setState(() {
        _settings = settings;
        _chapters = chapters;
        _tableOfContents = tableOfContents;
      });
    } else {
      _settings = settings;
      _chapters = chapters;
      _tableOfContents = tableOfContents;
    }
    return chapters;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _savePositionWithoutBlocking();
    }
  }

  void _savePositionWithoutBlocking() {
    unawaited(_enqueuePositionSave().catchError((Object _) {}));
  }

  Future<void> _enqueuePositionSave() {
    final locator = _locator;
    if (locator == null) return Future<void>.value();
    final position = ReadingPosition(
      bookId: widget.book.id,
      locator: locator,
      updatedAt: DateTime.now().toUtc(),
    );
    final save = _saveTail.then(
      (_) => widget.positionRepository.save(position),
    );
    _saveTail = save.catchError((Object _) {});
    return save;
  }

  void _showPosition(TextAnchor anchor) {
    _locator = ReadingLocator(anchor: anchor);
    _savePositionWithoutBlocking();
  }

  Future<void> _closeReader(Object? result) async {
    if (_closing) return;
    _closing = true;
    try {
      await _enqueuePositionSave();
    } catch (_) {
      // Closing the local reader must not be blocked by a persistence failure.
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop(result);
  }

  Future<void> _changeLayout() async {
    final updated = await showModalBottomSheet<ReaderSettings>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReaderLayoutControls(settings: _settings),
    );
    if (updated == null || updated == _settings || !mounted) return;
    try {
      await _enqueuePositionSave();
      await widget.settingsRepository.save(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reader settings could not be saved.')),
        );
      }
      return;
    }
    if (mounted) setState(() => _settings = updated);
  }

  Future<void> _showTableOfContents() async {
    final reference = await showReaderTableOfContents(
      context,
      _tableOfContents,
    );
    if (reference == null || !mounted) return;
    final chapter = _chapters.where(
      (candidate) => candidate.id == reference.chapterId,
    );
    if (chapter.isEmpty) {
      _showNavigationFailure();
      return;
    }
    final blocks = [...chapter.single.blocks]
      ..sort((left, right) => left.order.compareTo(right.order));
    if (blocks.isEmpty) {
      _showNavigationFailure();
      return;
    }
    final requestedBlockId = reference.blockId;
    final matchingBlocks = requestedBlockId == null
        ? const <ContentBlock>[]
        : blocks.where((block) => block.id == requestedBlockId).toList();
    if (requestedBlockId != null && matchingBlocks.isEmpty) {
      _showNavigationFailure();
      return;
    }
    final block = matchingBlocks.isEmpty ? blocks.first : matchingBlocks.single;
    final anchor = TextAnchor(
      bookId: widget.book.id,
      chapterId: chapter.single.id,
      blockId: block.id,
      startOffset: 0,
      endOffset: 0,
    );
    setState(() {
      _locator = ReadingLocator(anchor: anchor);
      _readerGeneration++;
    });
    _savePositionWithoutBlocking();
  }

  void _showNavigationFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This section could not be opened.')),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_closing) _savePositionWithoutBlocking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeData(_settings.theme);
    final systemUiStyle = _systemUiStyle(theme.colorScheme);
    return Theme(
      key: const ValueKey('reader-theme'),
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        key: const ValueKey('reader-system-ui-style'),
        value: systemUiStyle,
        child: PopScope<Object?>(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) unawaited(_closeReader(result));
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.book.title),
              systemOverlayStyle: systemUiStyle,
              actions: [
                IconButton(
                  tooltip: 'Table of contents',
                  onPressed: _tableOfContents.isEmpty
                      ? null
                      : _showTableOfContents,
                  icon: const Icon(Icons.list_alt),
                ),
                IconButton(
                  tooltip: 'Reader layout',
                  onPressed: _changeLayout,
                  icon: const Icon(Icons.text_fields),
                ),
              ],
            ),
            body: FutureBuilder<List<Chapter>>(
              future: _loading,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('The book could not be opened.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('This book has no readable content.'),
                  );
                }
                return SwipeableReader(
                  key: ValueKey('reader-generation-$_readerGeneration'),
                  chapters: snapshot.data!,
                  settings: _settings,
                  initialLocator: _locator,
                  onPositionChanged: _showPosition,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData _themeData(ReaderTheme readerTheme) {
  final colorScheme = switch (readerTheme) {
    ReaderTheme.light => ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.light,
    ),
    ReaderTheme.dark => ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    ),
    ReaderTheme.paper =>
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF795548),
        brightness: Brightness.light,
      ).copyWith(
        surface: const Color(0xFFF4ECD8),
        onSurface: const Color(0xFF2F261D),
        surfaceContainerHighest: const Color(0xFFE6D8BB),
      ),
  };
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
  );
}

SystemUiOverlayStyle _systemUiStyle(ColorScheme colorScheme) {
  final iconBrightness = colorScheme.brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: colorScheme.surface,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: colorScheme.brightness,
    systemNavigationBarColor: colorScheme.surface,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}
