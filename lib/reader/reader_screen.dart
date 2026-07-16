import 'dart:async';

import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/books/text_anchors.dart';
import 'package:flutter/material.dart';

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
    super.key,
  });

  final BookSummary book;
  final BookRepository bookRepository;
  final ReadingPositionRepository positionRepository;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  late final Future<List<Chapter>> _loading = _load();
  List<Chapter> _chapters = const [];
  int _chapterIndex = 0;
  ReadingLocator? _locator;
  Timer? _saveTimer;
  bool _restoreScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_schedulePositionSave);
  }

  Future<List<Chapter>> _load() async {
    final results = await Future.wait<Object?>([
      widget.bookRepository.loadChapters(widget.book.id),
      widget.positionRepository.load(widget.book.id),
    ]);
    final chapters = results[0]! as List<Chapter>;
    final saved = results[1] as ReadingPosition?;
    _chapters = chapters;
    _locator = saved?.locator;
    if (saved != null) {
      final index = chapters.indexWhere(
        (chapter) => chapter.id == saved.locator.anchor.chapterId,
      );
      if (index >= 0) _chapterIndex = index;
    }
    await _savePosition();
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

  void _schedulePositionSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), () {
      _savePositionWithoutBlocking();
    });
  }

  void _savePositionWithoutBlocking() {
    unawaited(_savePosition().catchError((Object _) {}));
  }

  TextAnchor? _currentAnchor() {
    if (_chapters.isEmpty || _chapterIndex >= _chapters.length) return null;
    final chapter = _chapters[_chapterIndex];
    if (chapter.blocks.isEmpty) return null;

    var blockIndex = 0;
    var atEnd = false;
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      final max = _scrollController.position.maxScrollExtent;
      final fraction = (_scrollController.offset / max).clamp(0.0, 1.0);
      blockIndex = (fraction * (chapter.blocks.length - 1)).round();
      atEnd = fraction >= 0.995;
    } else {
      final savedBlock = _locator?.anchor.blockId;
      final savedIndex = chapter.blocks.indexWhere(
        (block) => block.id == savedBlock,
      );
      if (savedIndex >= 0) blockIndex = savedIndex;
    }
    final block = chapter.blocks[blockIndex];
    final offset = atEnd ? _blockLength(block) : 0;
    return TextAnchor(
      bookId: widget.book.id,
      chapterId: chapter.id,
      blockId: block.id,
      startOffset: offset,
      endOffset: offset,
    );
  }

  Future<void> _savePosition() async {
    final anchor = _currentAnchor();
    if (anchor == null) return;
    final locator = ReadingLocator(anchor: anchor);
    _locator = locator;
    await widget.positionRepository.save(
      ReadingPosition(
        bookId: widget.book.id,
        locator: locator,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _restorePosition(Chapter chapter) {
    if (_restoreScheduled || chapter.blocks.isEmpty) return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final blockId = _locator?.anchor.blockId;
      final index = chapter.blocks.indexWhere((block) => block.id == blockId);
      if (index < 0 || chapter.blocks.length == 1) return;
      final fraction = index / (chapter.blocks.length - 1);
      _scrollController.jumpTo(
        _scrollController.position.maxScrollExtent * fraction,
      );
    });
  }

  void _showChapter(int index) {
    if (index < 0 || index >= _chapters.length || index == _chapterIndex) {
      return;
    }
    _savePositionWithoutBlocking();
    setState(() {
      _chapterIndex = index;
      _locator = null;
      _restoreScheduled = false;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _savePositionWithoutBlocking();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _savePositionWithoutBlocking();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.title)),
      body: FutureBuilder<List<Chapter>>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('The book could not be opened.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return const Center(
              child: Text('This book has no readable content.'),
            );
          }
          final chapter = snapshot.data![_chapterIndex];
          _restorePosition(chapter);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    Text(
                      chapter.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    for (final block in chapter.blocks)
                      _BlockView(block: block),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _chapterIndex == 0
                            ? null
                            : () => _showChapter(_chapterIndex - 1),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Previous'),
                      ),
                      Expanded(
                        child: Text(
                          '${_chapterIndex + 1} of ${_chapters.length}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _chapterIndex == _chapters.length - 1
                            ? null
                            : () => _showChapter(_chapterIndex + 1),
                        icon: const Icon(Icons.chevron_right),
                        iconAlignment: IconAlignment.end,
                        label: const Text('Next'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});

  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final block = this.block;
    final Widget content = switch (block) {
      HeadingBlock() => Text.rich(
        _spans(context, block.spans),
        style: _headingStyle(context, block.level),
      ),
      ParagraphBlock() => Text.rich(_spans(context, block.spans)),
      QuoteBlock() => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: Theme.of(context).dividerColor, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text.rich(
            _spans(context, block.spans),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      ),
      ListBlock() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < block.items.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${block.ordered ? '${index + 1}.' : '•'} ${block.items[index].text}',
              ),
            ),
        ],
      ),
      ImageBlock() => Semantics(
        image: true,
        label: block.altText,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 96),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.all(16),
          child: Text(block.caption ?? block.altText ?? 'Book image'),
        ),
      ),
    };
    return Padding(
      key: ValueKey(block.id),
      padding: const EdgeInsets.only(bottom: 16),
      child: DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
        child: content,
      ),
    );
  }

  static TextSpan _spans(BuildContext context, List<InlineTextSpan> spans) {
    return TextSpan(
      style: DefaultTextStyle.of(context).style,
      children: [
        for (final span in spans)
          TextSpan(
            text: span.text,
            style: TextStyle(
              fontWeight: span.bold ? FontWeight.bold : null,
              fontStyle: span.italic ? FontStyle.italic : null,
              decoration: span.underline || span.href != null
                  ? TextDecoration.underline
                  : null,
              color: span.href == null
                  ? null
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );
  }

  static TextStyle? _headingStyle(BuildContext context, int level) {
    final textTheme = Theme.of(context).textTheme;
    return switch (level) {
      1 => textTheme.headlineMedium,
      2 => textTheme.headlineSmall,
      3 => textTheme.titleLarge,
      _ => textTheme.titleMedium,
    };
  }
}

int _blockLength(ContentBlock block) => switch (block) {
  ParagraphBlock() => block.text.length,
  HeadingBlock() => block.text.length,
  QuoteBlock() => block.text.length,
  ListBlock() => block.items.fold<int>(
    0,
    (total, item) => total + item.text.length,
  ),
  ImageBlock() => 1,
};
