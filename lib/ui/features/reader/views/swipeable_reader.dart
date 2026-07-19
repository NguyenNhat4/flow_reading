import 'dart:async';
import 'dart:math' as math;

import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/highlight.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/ui/features/reader/services/flutter_content_measurer.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_pagination_view_model.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_selection.dart';
import 'package:flow_reading/ui/features/reader/views/reader_action_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeableReader extends StatefulWidget {
  const SwipeableReader({
    required this.chapters,
    required this.settings,
    required this.onPositionChanged,
    this.pagination,
    this.initialLocator,
    this.onWordSelected,
    this.onPassageSelected,
    this.onActionSelected,
    this.highlights = const [],
    super.key,
  });

  final List<Chapter> chapters;
  final ReaderSettings settings;
  final ReadingLocator? initialLocator;
  final ValueChanged<TextAnchor> onPositionChanged;
  final ReaderPaginationViewModel? pagination;

  /// Receives a stable range whenever the reader selects a word.
  final ValueChanged<WordSelection>? onWordSelected;

  /// Receives a stable range whenever reader handles adjust a passage.
  final ValueChanged<PassageSelection>? onPassageSelected;

  /// Opens a workflow for an action and its stable canonical selection.
  final ReaderActionHandler? onActionSelected;
  final List<Highlight> highlights;

  @override
  State<SwipeableReader> createState() => _SwipeableReaderState();
}

class _SwipeableReaderState extends State<SwipeableReader> {
  static const _measurer = FlutterContentMeasurer();

  late final ReaderPaginationViewModel _pagination;
  PageController? _pageController;
  WordSelection? _wordSelection;
  PassageSelection? _passageSelection;

  @override
  void initState() {
    super.initState();
    _pagination =
        widget.pagination ?? ReaderPaginationViewModel(measurer: _measurer);
    if (widget.pagination != null) _pagination.invalidate();
  }

  @override
  void didUpdateWidget(covariant SwipeableReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_chaptersChanged(oldWidget.chapters, widget.chapters) ||
        _paginationSettingsChanged(oldWidget.settings, widget.settings)) {
      _pagination.invalidate();
    }
  }

  static bool _chaptersChanged(List<Chapter> before, List<Chapter> after) {
    if (before.length != after.length) return true;
    for (var index = 0; index < before.length; index++) {
      if (!identical(before[index], after[index])) return true;
    }
    return false;
  }

  @override
  void dispose() {
    if (widget.pagination == null) _pagination.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _pagination,
      builder: (context, _) {
        final pagination = _pagination.state;
        final pages = pagination.pages;
        return Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (!constraints.hasBoundedWidth ||
                      !constraints.hasBoundedHeight ||
                      constraints.maxWidth <= 0 ||
                      constraints.maxHeight <= 0) {
                    return const Center(
                      child: Text('The reader viewport is not available.'),
                    );
                  }
                  final layout = ReaderLayout(
                    settings: widget.settings,
                    viewportWidth: constraints.maxWidth,
                    viewportHeight: constraints.maxHeight,
                    textScale: MediaQuery.textScalerOf(context).scale(1),
                  );
                  _ensurePagination(layout);
                  if (pagination.status == PaginationStatus.failure &&
                      pagination.requestedLayoutKey ==
                          layout.paginationCacheKey) {
                    return const Center(
                      child: Text('This book could not be paginated.'),
                    );
                  }
                  if (pagination.activeLayoutKey != layout.paginationCacheKey) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (pages.isEmpty) {
                    return const Center(
                      child: Text('This book has no readable content.'),
                    );
                  }
                  return PageView.builder(
                    key: const ValueKey('reader-page-view'),
                    controller: _pageController,
                    itemCount: pages.length,
                    allowImplicitScrolling: true,
                    physics: const PageScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    onPageChanged: _showPage,
                    itemBuilder: (context, index) => _ReaderPageContent(
                      key: ValueKey(
                        'reader-page-${pages[index].chapter.id}-${pages[index].boundary.pageIndex}',
                      ),
                      page: pages[index],
                      layout: layout,
                      measurer: _measurer,
                      wordSelection: _wordSelection,
                      passageSelection: _passageSelection,
                      highlights: widget.highlights,
                      onWordSelected: _selectWord,
                      onPassageSelected: _selectPassage,
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: SizedBox(
                height: 52,
                child: Center(
                  child: _selectedRequest != null
                      ? ReaderActionMenu(
                          actions: _passageSelection == null
                              ? wordReaderActions
                              : passageReaderActions,
                          removeHighlight: widget.highlights.any(
                            (highlight) =>
                                highlight.id == _selectedRequest?.anchor.id,
                          ),
                          onSelected: _performAction,
                        )
                      : pages.isEmpty
                      ? const SizedBox.shrink()
                      : Semantics(
                          liveRegion: true,
                          label:
                              '${pages[pagination.currentPage].chapter.title}, page ${pagination.currentPage + 1} of ${pages.length}',
                          child: Text(
                            '${pages[pagination.currentPage].chapter.title} · Page ${pagination.currentPage + 1} of ${pages.length}',
                            key: const ValueKey('reader-page-indicator'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _ensurePagination(ReaderLayout layout) {
    final key = layout.paginationCacheKey;
    if (_pagination.state.requestedLayoutKey == key) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pagination.state.requestedLayoutKey != key) {
        unawaited(_paginate(layout));
      }
    });
  }

  Future<void> _paginate(ReaderLayout layout) async {
    final previous = _pagination.state;
    final target = previous.pages.isNotEmpty
        ? ReadingLocator(
            anchor: previous.pages[previous.currentPage].boundary.start,
          )
        : widget.initialLocator;
    await _pagination.paginate(
      chapters: widget.chapters,
      layout: layout,
      target: target,
    );
    if (!mounted) return;
    final state = _pagination.state;
    if (state.status != PaginationStatus.ready ||
        state.activeLayoutKey != layout.paginationCacheKey) {
      return;
    }
    final oldController = _pageController;
    final controller = PageController(initialPage: state.currentPage);
    setState(() => _pageController = controller);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController?.dispose();
      if (mounted && state.pages.isNotEmpty) {
        widget.onPositionChanged(state.pages[state.currentPage].boundary.start);
      }
    });
  }

  void _showPage(int index) {
    final anchor = _pagination.showPage(index);
    if (anchor == null) return;
    setState(() {
      _wordSelection = null;
      _passageSelection = null;
    });
    widget.onPositionChanged(anchor);
  }

  void _selectWord(WordSelection? selection) {
    setState(() {
      _wordSelection = selection;
      _passageSelection = null;
    });
    if (selection != null) widget.onWordSelected?.call(selection);
  }

  void _selectPassage(PassageSelection selection) {
    setState(() {
      _wordSelection = null;
      _passageSelection = selection;
    });
    widget.onPassageSelected?.call(selection);
  }

  ReaderActionRequest? get _selectedRequest {
    final passage = _passageSelection;
    if (passage != null) {
      return ReaderActionRequest(
        action: ReaderAction.copy,
        selectionKind: ReaderSelectionKind.passage,
        anchor: passage.anchor,
        textSnapshot: passage.textSnapshot,
      );
    }
    final word = _wordSelection;
    if (word == null) return null;
    return ReaderActionRequest(
      action: ReaderAction.copy,
      selectionKind: ReaderSelectionKind.word,
      anchor: word.anchor,
      textSnapshot: word.textSnapshot,
    );
  }

  Future<void> _performAction(ReaderAction action) async {
    final selected = _selectedRequest;
    if (selected == null) return;
    final request = ReaderActionRequest(
      action: action,
      selectionKind: selected.selectionKind,
      anchor: selected.anchor,
      textSnapshot: selected.textSnapshot,
    );
    try {
      if (action == ReaderAction.copy) {
        await Clipboard.setData(ClipboardData(text: request.textSnapshot));
      }
      final handler = widget.onActionSelected;
      if (handler != null) {
        await handler(request);
      } else if (action.requiresInternet && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${action.label} requires internet access.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${action.label} could not be opened.')),
      );
    }
  }
}

bool _paginationSettingsChanged(ReaderSettings left, ReaderSettings right) =>
    left.fontFamily != right.fontFamily ||
    left.fontSize != right.fontSize ||
    left.lineHeight != right.lineHeight ||
    left.margins != right.margins ||
    left.languageMode != right.languageMode;

class _ReaderPageContent extends StatelessWidget {
  const _ReaderPageContent({
    required this.page,
    required this.layout,
    required this.measurer,
    required this.wordSelection,
    required this.passageSelection,
    required this.highlights,
    required this.onWordSelected,
    required this.onPassageSelected,
    super.key,
  });

  final ReaderPage page;
  final ReaderLayout layout;
  final FlutterContentMeasurer measurer;
  final WordSelection? wordSelection;
  final PassageSelection? passageSelection;
  final List<Highlight> highlights;
  final ValueChanged<WordSelection?> onWordSelected;
  final ValueChanged<PassageSelection> onPassageSelected;

  @override
  Widget build(BuildContext context) {
    final blocks = [...page.chapter.blocks]
      ..sort((left, right) => left.order.compareTo(right.order));
    final startIndex = blocks.indexWhere(
      (block) => block.id == page.boundary.start.blockId,
    );
    final endIndex = blocks.indexWhere(
      (block) => block.id == page.boundary.end.blockId,
    );
    if (startIndex < 0 || endIndex < startIndex) {
      return const Center(child: Text('This page could not be displayed.'));
    }

    final fragments = <Widget>[];
    for (var index = startIndex; index <= endIndex; index++) {
      final block = blocks[index];
      final startOffset = index == startIndex
          ? page.boundary.start.startOffset
          : 0;
      final endOffset = index == endIndex
          ? page.boundary.end.startOffset
          : measurer.sourceLength(block);
      if (endOffset <= startOffset) continue;
      fragments.add(
        _BlockFragment(
          bookId: page.chapter.bookId,
          block: block,
          startOffset: startOffset,
          endOffset: endOffset,
          layout: layout,
          measurer: measurer,
          wordSelection: wordSelection,
          passageSelection: passageSelection,
          highlights: highlights
              .where(
                (highlight) =>
                    highlight.range.chapterId == block.chapterId &&
                    highlight.range.blockId == block.id,
              )
              .toList(growable: false),
          onWordSelected: onWordSelected,
          onPassageSelected: onPassageSelected,
        ),
      );
    }

    final margins = layout.settings.margins;
    return ClipRect(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          margins.left,
          margins.top,
          margins.right,
          margins.bottom,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < fragments.length; index++) ...[
                if (index > 0) const SizedBox(height: 16),
                fragments[index],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockFragment extends StatelessWidget {
  const _BlockFragment({
    required this.bookId,
    required this.block,
    required this.startOffset,
    required this.endOffset,
    required this.layout,
    required this.measurer,
    required this.wordSelection,
    required this.passageSelection,
    required this.highlights,
    required this.onWordSelected,
    required this.onPassageSelected,
  });

  final String bookId;
  final ContentBlock block;
  final int startOffset;
  final int endOffset;
  final ReaderLayout layout;
  final FlutterContentMeasurer measurer;
  final WordSelection? wordSelection;
  final PassageSelection? passageSelection;
  final List<Highlight> highlights;
  final ValueChanged<WordSelection?> onWordSelected;
  final ValueChanged<PassageSelection> onPassageSelected;

  @override
  Widget build(BuildContext context) {
    final block = this.block;
    if (block is ImageBlock) {
      return SizedBox(
        height: math.min(
          FlutterContentMeasurer.imagePlaceholderHeight,
          layout.contentHeight,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(block.caption ?? block.altText ?? 'Book image'),
            ),
          ),
        ),
      );
    }

    final selectedAnchor = passageSelection?.anchor ?? wordSelection?.anchor;
    final selectsBlock =
        selectedAnchor != null &&
        selectedAnchor.bookId == bookId &&
        selectedAnchor.chapterId == block.chapterId &&
        selectedAnchor.blockId == block.id;
    final span = measurer.textSpanForRange(
      block: block,
      settings: layout.settings,
      startOffset: startOffset,
      endOffset: endOffset,
      selectedStartOffset: selectsBlock ? selectedAnchor.startOffset : null,
      selectedEndOffset: selectsBlock ? selectedAnchor.endOffset : null,
      selectionColor: Theme.of(context).colorScheme.primaryContainer,
      highlights: highlights.map((highlight) => highlight.range).toList(),
      highlightColor: Theme.of(context).colorScheme.tertiaryContainer,
    );
    final selectedHere =
        selectsBlock &&
        selectedAnchor.startOffset < endOffset &&
        selectedAnchor.endOffset > startOffset;
    final text = _TappableTextFragment(
      selectedWord: selectedHere && passageSelection == null
          ? wordSelection?.textSnapshot
          : null,
      selectedPassage:
          passageSelection?.anchor.bookId == bookId &&
              passageSelection?.anchor.chapterId == block.chapterId &&
              passageSelection?.anchor.blockId == block.id
          ? passageSelection?.textSnapshot
          : null,
      text: TextSpan(
        style: TextStyle(color: DefaultTextStyle.of(context).style.color),
        children: [span],
      ),
      textScale: layout.textScale,
      onTapDisplayOffset: (displayOffset) {
        final sourceOffset = measurer.sourceOffsetForDisplayPosition(
          block: block,
          settings: layout.settings,
          startOffset: startOffset,
          endOffset: endOffset,
          displayOffset: displayOffset,
        );
        if (sourceOffset == null) {
          onWordSelected(null);
          return;
        }
        onWordSelected(
          wordSelectionAt(
            bookId: bookId,
            chapterId: block.chapterId,
            blockId: block.id,
            sourceText: measurer.sourceText(block, layout.settings),
            sourceOffset: sourceOffset,
          ),
        );
      },
      onDisplaySelectionChanged: (selection) {
        int? sourceStart;
        for (
          var displayOffset = selection.start;
          displayOffset < selection.end;
          displayOffset++
        ) {
          sourceStart = measurer.sourceOffsetForDisplayPosition(
            block: block,
            settings: layout.settings,
            startOffset: startOffset,
            endOffset: endOffset,
            displayOffset: displayOffset,
          );
          if (sourceStart != null) break;
        }
        int? sourceEnd;
        for (
          var displayOffset = selection.end - 1;
          displayOffset >= selection.start;
          displayOffset--
        ) {
          final sourceOffset = measurer.sourceOffsetForDisplayPosition(
            block: block,
            settings: layout.settings,
            startOffset: startOffset,
            endOffset: endOffset,
            displayOffset: displayOffset,
          );
          if (sourceOffset == null) continue;
          sourceEnd = sourceOffset + 1;
          break;
        }
        if (sourceStart == null || sourceEnd == null) return;
        final passage = passageSelectionForRange(
          bookId: bookId,
          chapterId: block.chapterId,
          blockId: block.id,
          sourceText: measurer.sourceText(block, layout.settings),
          startOffset: sourceStart,
          endOffset: sourceEnd,
        );
        if (passage != null) onPassageSelected(passage);
      },
    );
    if (block is QuoteBlock) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: Theme.of(context).dividerColor, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: FlutterContentMeasurer.quoteInset,
          ),
          child: text,
        ),
      );
    }
    return text;
  }
}

class _TappableTextFragment extends StatefulWidget {
  const _TappableTextFragment({
    required this.text,
    required this.textScale,
    required this.onTapDisplayOffset,
    required this.onDisplaySelectionChanged,
    this.selectedWord,
    this.selectedPassage,
  });

  final TextSpan text;
  final double textScale;
  final ValueChanged<int> onTapDisplayOffset;
  final ValueChanged<TextSelection> onDisplaySelectionChanged;
  final String? selectedWord;
  final String? selectedPassage;

  @override
  State<_TappableTextFragment> createState() => _TappableTextFragmentState();
}

class _TappableTextFragmentState extends State<_TappableTextFragment> {
  final _textKey = GlobalKey();
  int? _lastPointerDisplayOffset;
  TextSelection? _pendingLongPressSelection;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.selectedPassage == null
        ? widget.selectedWord == null
              ? null
              : 'Selected word: ${widget.selectedWord}'
        : 'Selected passage: ${widget.selectedPassage}';
    final passageSelection = _displaySelectionFor(widget.selectedPassage);
    return Semantics(
      selected: selectedLabel != null,
      label: selectedLabel,
      child: GestureDetector(
        key: widget.selectedPassage != null
            ? const ValueKey('reader-selected-passage')
            : widget.selectedWord != null
            ? const ValueKey('reader-selected-word')
            : null,
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          final size = context.size;
          if (size == null || size.width <= 0) return;
          final position = _displayPosition(details.localPosition, size.width);
          _lastPointerDisplayOffset = position.offset;
          final range = wordRangeAt(
            widget.text.toPlainText(),
            position.offset.clamp(0, widget.text.toPlainText().length - 1),
          );
          _pendingLongPressSelection = range == null
              ? null
              : TextSelection(
                  baseOffset: range.startOffset,
                  extentOffset: range.endOffset,
                );
          widget.onTapDisplayOffset(position.offset);
        },
        onLongPressStart: (_) {
          final selection = _pendingLongPressSelection;
          if (selection != null) {
            widget.onDisplaySelectionChanged(selection);
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            clipBehavior: Clip.none,
            children: [
              RichText(
                key: _textKey,
                text: widget.text,
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.linear(widget.textScale),
              ),
              if (passageSelection != null)
                ..._selectionHandles(passageSelection, constraints.maxWidth),
            ],
          ),
        ),
      ),
    );
  }

  TextPosition _displayPosition(Offset localPosition, double maxWidth) {
    final painter = TextPainter(
      text: widget.text,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(widget.textScale),
    )..layout(maxWidth: maxWidth);
    final position = painter.getPositionForOffset(localPosition);
    painter.dispose();
    return position;
  }

  List<Widget> _selectionHandles(TextSelection selection, double maxWidth) {
    final painter = TextPainter(
      text: widget.text,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(widget.textScale),
    )..layout(maxWidth: maxWidth);
    final boxes = painter.getBoxesForSelection(selection);
    painter.dispose();
    if (boxes.isEmpty) return const [];
    final start = boxes.first;
    final end = boxes.last;
    return [
      Positioned(
        left: start.left - 16,
        top: start.bottom - 4,
        child: _SelectionHandle(
          key: const ValueKey('reader-passage-start-handle'),
          onDrag: (globalPosition) =>
              _moveHandle(globalPosition, selection, maxWidth, moveStart: true),
        ),
      ),
      Positioned(
        left: end.right - 16,
        top: end.bottom - 4,
        child: _SelectionHandle(
          key: const ValueKey('reader-passage-end-handle'),
          onDrag: (globalPosition) => _moveHandle(
            globalPosition,
            selection,
            maxWidth,
            moveStart: false,
          ),
        ),
      ),
    ];
  }

  void _moveHandle(
    Offset globalPosition,
    TextSelection selection,
    double maxWidth, {
    required bool moveStart,
  }) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final position = _displayPosition(
      renderObject.globalToLocal(globalPosition),
      maxWidth,
    ).offset;
    final updated = moveStart
        ? TextSelection(
            baseOffset: position.clamp(0, selection.end - 1),
            extentOffset: selection.end,
          )
        : TextSelection(
            baseOffset: selection.start,
            extentOffset: position.clamp(
              selection.start + 1,
              widget.text.toPlainText().length,
            ),
          );
    widget.onDisplaySelectionChanged(updated);
  }

  TextSelection? _displaySelectionFor(String? selectedText) {
    if (selectedText == null || selectedText.isEmpty) return null;
    final displayText = widget.text.toPlainText();
    final candidates = <int>[];
    var searchStart = 0;
    while (searchStart <= displayText.length - selectedText.length) {
      final index = displayText.indexOf(selectedText, searchStart);
      if (index < 0) break;
      candidates.add(index);
      searchStart = index + 1;
    }
    if (candidates.isEmpty) return null;
    final hint = _lastPointerDisplayOffset;
    var best = candidates.first;
    if (hint != null) {
      var bestDistance = _selectionDistance(best, selectedText.length, hint);
      for (final candidate in candidates.skip(1)) {
        final distance = _selectionDistance(
          candidate,
          selectedText.length,
          hint,
        );
        if (distance < bestDistance) {
          best = candidate;
          bestDistance = distance;
        }
      }
    }
    return TextSelection(
      baseOffset: best,
      extentOffset: best + selectedText.length,
    );
  }
}

class _SelectionHandle extends StatelessWidget {
  const _SelectionHandle({required this.onDrag, super.key});

  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => onDrag(details.globalPosition),
      child: SizedBox.square(
        dimension: 32,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 14),
          ),
        ),
      ),
    );
  }
}

int _selectionDistance(int start, int length, int hint) {
  final end = start + length;
  if (hint >= start && hint <= end) return 0;
  return hint < start ? start - hint : hint - end;
}
