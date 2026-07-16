import 'dart:math' as math;

import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/reader/pagination_engine.dart';
import 'package:flow_reading/settings/reader_settings.dart';
import 'package:flutter/material.dart';

final class FlutterContentMeasurer implements ContentMeasurer {
  const FlutterContentMeasurer();

  static const imagePlaceholderHeight = 128.0;
  static const listItemSpacing = 6.0;

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
    final painter = TextPainter(
      text: text,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(layout.textScale),
    )..layout(maxWidth: maxWidth);
    try {
      final completeHeight =
          painter.height +
          projection.spacingBetween(startOffset, projection.sourceLength);
      if (completeHeight <= maxHeight + 0.001) {
        return BlockMeasurement(
          endOffset: projection.sourceLength,
          height: completeHeight,
        );
      }

      final lines = painter.computeLineMetrics();
      var textHeight = 0.0;
      var fittedHeight = 0.0;
      var sourceEnd = startOffset;
      for (final line in lines) {
        textHeight += line.height;
        final lineSourceEnd = _sourceEndForLine(
          painter,
          line,
          projection,
          displayStart,
          maxWidth,
        );
        final height =
            textHeight + projection.spacingBetween(startOffset, lineSourceEnd);
        if (height > maxHeight + 0.001) break;
        fittedHeight = height;
        sourceEnd = lineSourceEnd;
      }
      if (sourceEnd <= startOffset) {
        return BlockMeasurement(endOffset: startOffset, height: 0);
      }
      return BlockMeasurement(endOffset: sourceEnd, height: fittedHeight);
    } finally {
      painter.dispose();
    }
  }

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
    required this.listItemEnds,
  });

  final List<_StyledRun> runs;
  final List<int> displayToSource;
  final int sourceLength;
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
    final children = <InlineSpan>[];
    for (final run in runs) {
      if (run.end <= displayStart) continue;
      final localStart = math.max(displayStart, run.start) - run.start;
      children.add(
        TextSpan(text: run.text.substring(localStart), style: run.style),
      );
    }
    return TextSpan(children: children);
  }
}

final class _ProjectionBuilder {
  final List<_StyledRun> _runs = [];
  final List<int> _displayToSource = [0];
  final List<int> _listItemEnds = [];
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
    listItemEnds: List.unmodifiable(_listItemEnds),
  );
}
