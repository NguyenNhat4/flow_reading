import 'dart:math' as math;

import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/use_cases/paginate_chapter.dart';
import 'package:flutter/material.dart';

final class FlutterContentMeasurer implements ContentMeasurer {
  const FlutterContentMeasurer();

  static const imagePlaceholderHeight = 128.0;
  static const listItemSpacing = 6.0;
  static const quoteInset = 16.0;

  @override
  int sourceLength(ContentBlock block) => switch (block) {
    ParagraphBlock() => block.text.length,
    HeadingBlock() => block.text.length,
    QuoteBlock() => block.text.length,
    ListBlock() => _projection(block, ReaderSettings.defaults).sourceLength,
    ImageBlock() => 1,
  };

  @override
  BlockMeasurement measure({
    required ContentBlock block,
    required int startOffset,
    required double maxWidth,
    required double maxHeight,
    required ReaderLayout layout,
  }) {
    final length = sourceLength(block);
    if (startOffset < 0 || startOffset > length) {
      throw RangeError.range(startOffset, 0, length, 'startOffset');
    }
    if (startOffset == length || maxWidth <= 0 || maxHeight <= 0) {
      return BlockMeasurement(endOffset: startOffset, height: 0);
    }
    if (block is ImageBlock) {
      final height = math.min(imagePlaceholderHeight, layout.contentHeight);
      return maxHeight + 0.001 >= height
          ? BlockMeasurement(endOffset: 1, height: height)
          : BlockMeasurement(endOffset: startOffset, height: 0);
    }

    final projection = _projection(block, layout.settings);
    final displayStart = projection.displayOffsetForSource(startOffset);
    final text = projection.spanFrom(displayStart);
    final textWidth = block is QuoteBlock ? maxWidth - quoteInset : maxWidth;
    if (textWidth <= 0) {
      return BlockMeasurement(endOffset: startOffset, height: 0);
    }
    final maxLines = math.max(
      1,
      (maxHeight / math.max(1, layout.settings.fontSize * layout.textScale))
              .ceil() +
          2,
    );
    final painter = TextPainter(
      text: text,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(layout.textScale),
      maxLines: maxLines,
    )..layout(maxWidth: textWidth);
    try {
      final completeHeight =
          painter.height +
          projection.spacingBetween(startOffset, projection.sourceLength);
      if (!painter.didExceedMaxLines && completeHeight <= maxHeight + 0.001) {
        return BlockMeasurement(
          endOffset: projection.sourceLength,
          height: completeHeight,
        );
      }

      final lines = painter.computeLineMetrics();
      var textHeight = 0.0;
      final candidateEnds = <int>[];
      for (final line in lines) {
        textHeight += line.height;
        final lineSourceEnd = _sourceEndForLine(
          painter,
          line,
          projection,
          displayStart,
          textWidth,
        );
        final height =
            textHeight + projection.spacingBetween(startOffset, lineSourceEnd);
        if (height > maxHeight + 0.001) break;
        if (lineSourceEnd > startOffset &&
            (candidateEnds.isEmpty || candidateEnds.last != lineSourceEnd)) {
          candidateEnds.add(lineSourceEnd);
        }
      }
      for (final sourceEnd in candidateEnds.reversed) {
        final height = _exactRangeHeight(
          projection: projection,
          startOffset: startOffset,
          endOffset: sourceEnd,
          maxWidth: textWidth,
          textScale: layout.textScale,
        );
        if (height <= maxHeight + 0.001) {
          return BlockMeasurement(endOffset: sourceEnd, height: height);
        }
      }
      return BlockMeasurement(endOffset: startOffset, height: 0);
    } finally {
      painter.dispose();
    }
  }

  static double _exactRangeHeight({
    required _TextProjection projection,
    required int startOffset,
    required int endOffset,
    required double maxWidth,
    required double textScale,
  }) {
    final displayStart = projection.displayOffsetForSource(startOffset);
    final displayEnd = projection.displayOffsetForSource(endOffset);
    final painter = TextPainter(
      text: projection.spanBetween(displayStart, displayEnd),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(textScale),
    )..layout(maxWidth: maxWidth);
    try {
      return painter.height + projection.spacingBetween(startOffset, endOffset);
    } finally {
      painter.dispose();
    }
  }

  TextSpan textSpanForRange({
    required ContentBlock block,
    required ReaderSettings settings,
    required int startOffset,
    required int endOffset,
    int? selectedStartOffset,
    int? selectedEndOffset,
    Color? selectionColor,
    List<TextAnchor> highlights = const [],
    Color? highlightColor,
  }) {
    if (block is ImageBlock) {
      throw ArgumentError.value(block, 'block', 'images do not contain text');
    }
    final projection = _projection(block, settings);
    if (startOffset < 0 ||
        endOffset < startOffset ||
        endOffset > projection.sourceLength) {
      throw RangeError.range(
        endOffset,
        startOffset,
        projection.sourceLength,
        'endOffset',
      );
    }
    final displayStart = projection.displayOffsetForSource(startOffset);
    final displayEnd = projection.displayOffsetForSource(endOffset);
    final boundaries = <int>{startOffset, endOffset};
    if (selectedStartOffset != null &&
        selectedEndOffset != null &&
        selectionColor != null) {
      boundaries
        ..add(selectedStartOffset.clamp(startOffset, endOffset))
        ..add(selectedEndOffset.clamp(startOffset, endOffset));
    }
    if (highlightColor != null) {
      for (final highlight in highlights) {
        if (highlight.startOffset < endOffset &&
            highlight.endOffset > startOffset) {
          boundaries
            ..add(highlight.startOffset.clamp(startOffset, endOffset))
            ..add(highlight.endOffset.clamp(startOffset, endOffset));
        }
      }
    }
    final offsets = boundaries.toList()..sort();
    if (offsets.length == 2) {
      return projection.spanBetween(displayStart, displayEnd);
    }
    return TextSpan(
      children: [
        for (var index = 0; index < offsets.length - 1; index++)
          _decoratedSpan(
            projection: projection,
            startOffset: offsets[index],
            endOffset: offsets[index + 1],
            selectedStartOffset: selectedStartOffset,
            selectedEndOffset: selectedEndOffset,
            selectionColor: selectionColor,
            highlights: highlights,
            highlightColor: highlightColor,
          ),
      ],
    );
  }

  static TextSpan _decoratedSpan({
    required _TextProjection projection,
    required int startOffset,
    required int endOffset,
    required int? selectedStartOffset,
    required int? selectedEndOffset,
    required Color? selectionColor,
    required List<TextAnchor> highlights,
    required Color? highlightColor,
  }) {
    final selected =
        selectionColor != null &&
        selectedStartOffset != null &&
        selectedEndOffset != null &&
        selectedStartOffset < endOffset &&
        selectedEndOffset > startOffset;
    final highlighted =
        !selected &&
        highlightColor != null &&
        highlights.any(
          (highlight) =>
              highlight.startOffset < endOffset &&
              highlight.endOffset > startOffset,
        );
    final span = projection.spanBetween(
      projection.displayOffsetForSource(startOffset),
      projection.displayOffsetForSource(endOffset),
    );
    final color = selected
        ? selectionColor
        : highlighted
        ? highlightColor
        : null;
    return color == null
        ? span
        : TextSpan(
            style: TextStyle(backgroundColor: color),
            children: [span],
          );
  }

  /// Maps a display character in a rendered fragment back to its canonical
  /// UTF-16 source offset. Decorations such as list markers return `null`.
  int? sourceOffsetForDisplayPosition({
    required ContentBlock block,
    required ReaderSettings settings,
    required int startOffset,
    required int endOffset,
    required int displayOffset,
  }) {
    final projection = _projection(block, settings);
    final displayStart = projection.displayOffsetForSource(startOffset);
    final displayEnd = projection.displayOffsetForSource(endOffset);
    if (displayEnd <= displayStart) return null;
    final absoluteDisplay = (displayStart + displayOffset).clamp(
      displayStart,
      displayEnd - 1,
    );
    if (projection.displayToSource[absoluteDisplay] ==
        projection.displayToSource[absoluteDisplay + 1]) {
      return null;
    }
    return projection.sourceOffsetForDisplay(absoluteDisplay);
  }

  /// Returns the canonical source text used by stable offsets for [block].
  String sourceText(ContentBlock block, ReaderSettings settings) =>
      _projection(block, settings).sourceText;

  static int _sourceEndForLine(
    TextPainter painter,
    LineMetrics line,
    _TextProjection projection,
    int displayStart,
    double maxWidth,
  ) {
    final position = painter.getPositionForOffset(
      Offset(maxWidth, line.baseline - line.ascent / 2),
    );
    final lineBoundary = painter.getLineBoundary(position);
    final absoluteDisplayEnd = math.min(
      projection.displayLength,
      displayStart + lineBoundary.end,
    );
    return projection.sourceOffsetForDisplay(absoluteDisplayEnd);
  }

  static _TextProjection _projection(
    ContentBlock block,
    ReaderSettings settings,
  ) {
    final builder = _ProjectionBuilder();
    final base = _baseStyle(block, settings);
    switch (block) {
      case ParagraphBlock():
        builder.addInlineSpans(block.spans, base);
      case HeadingBlock():
        builder.addInlineSpans(block.spans, base);
      case QuoteBlock():
        builder.addInlineSpans(block.spans, base);
      case ListBlock():
        _addListItems(builder, block.items, block.ordered, base, 0);
      case ImageBlock():
        throw StateError('Images do not have text projections.');
    }
    return builder.build();
  }

  static void _addListItems(
    _ProjectionBuilder builder,
    List<BookListItem> items,
    bool ordered,
    TextStyle style,
    int depth,
  ) {
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final marker = ordered ? '${index + 1}. ' : '• ';
      builder.addDecoration('${'  ' * depth}$marker', style);
      builder.addInlineSpans(item.spans, style);
      builder.addSource('\n', style);
      builder.markListItemEnd();
      if (item.children.isNotEmpty) {
        _addListItems(builder, item.children, ordered, style, depth + 1);
      }
    }
  }

  static TextStyle _baseStyle(ContentBlock block, ReaderSettings settings) {
    final base = TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
    );
    return switch (block) {
      HeadingBlock() => base.copyWith(
        fontSize: settings.fontSize * _headingScale(block.level),
        fontWeight: FontWeight.w600,
      ),
      QuoteBlock() => base.copyWith(fontStyle: FontStyle.italic),
      _ => base,
    };
  }

  static double _headingScale(int level) => switch (level) {
    1 => 1.6,
    2 => 1.4,
    3 => 1.2,
    _ => 1.1,
  };
}

final class _StyledRun {
  const _StyledRun({
    required this.start,
    required this.end,
    required this.text,
    required this.style,
  });

  final int start;
  final int end;
  final String text;
  final TextStyle style;
}

final class _TextProjection {
  const _TextProjection({
    required this.runs,
    required this.displayToSource,
    required this.sourceLength,
    required this.sourceText,
    required this.listItemEnds,
  });

  final List<_StyledRun> runs;
  final List<int> displayToSource;
  final int sourceLength;
  final String sourceText;
  final List<int> listItemEnds;

  int get displayLength => displayToSource.length - 1;

  int displayOffsetForSource(int sourceOffset) {
    final index = displayToSource.indexOf(sourceOffset);
    if (index < 0) {
      throw StateError('Source offset has no display projection.');
    }
    return index;
  }

  int sourceOffsetForDisplay(int displayOffset) =>
      displayToSource[displayOffset.clamp(0, displayLength)];

  double spacingBetween(int startOffset, int endOffset) {
    final itemCount = listItemEnds
        .where((offset) => offset > startOffset && offset <= endOffset)
        .length;
    return itemCount * FlutterContentMeasurer.listItemSpacing;
  }

  TextSpan spanFrom(int displayStart) {
    return spanBetween(displayStart, displayLength);
  }

  TextSpan spanBetween(int displayStart, int displayEnd) {
    final children = <InlineSpan>[];
    for (final run in runs) {
      if (run.end <= displayStart) continue;
      if (run.start >= displayEnd) break;
      final localStart = math.max(displayStart, run.start) - run.start;
      final localEnd = math.min(displayEnd, run.end) - run.start;
      children.add(
        TextSpan(
          text: run.text.substring(localStart, localEnd),
          style: run.style,
        ),
      );
    }
    return TextSpan(children: children);
  }
}

final class _ProjectionBuilder {
  final List<_StyledRun> _runs = [];
  final List<int> _displayToSource = [0];
  final List<int> _listItemEnds = [];
  final StringBuffer _sourceText = StringBuffer();
  var _displayOffset = 0;
  var _sourceOffset = 0;

  void addInlineSpans(List<InlineTextSpan> spans, TextStyle base) {
    for (final span in spans) {
      addSource(
        span.text,
        base.copyWith(
          fontWeight: span.bold ? FontWeight.bold : null,
          fontStyle: span.italic ? FontStyle.italic : null,
          decoration: span.underline || span.href != null
              ? TextDecoration.underline
              : null,
        ),
      );
    }
  }

  void addSource(String text, TextStyle style) {
    _addRun(text, style);
    _sourceText.write(text);
    for (var index = 0; index < text.length; index++) {
      _sourceOffset++;
      _displayToSource.add(_sourceOffset);
    }
  }

  void addDecoration(String text, TextStyle style) {
    _addRun(text, style);
    for (var index = 0; index < text.length; index++) {
      _displayToSource.add(_sourceOffset);
    }
  }

  void markListItemEnd() => _listItemEnds.add(_sourceOffset);

  void _addRun(String text, TextStyle style) {
    if (text.isEmpty) return;
    _runs.add(
      _StyledRun(
        start: _displayOffset,
        end: _displayOffset + text.length,
        text: text,
        style: style,
      ),
    );
    _displayOffset += text.length;
  }

  _TextProjection build() => _TextProjection(
    runs: List.unmodifiable(_runs),
    displayToSource: List.unmodifiable(_displayToSource),
    sourceLength: _sourceOffset,
    sourceText: _sourceText.toString(),
    listItemEnds: List.unmodifiable(_listItemEnds),
  );
}
