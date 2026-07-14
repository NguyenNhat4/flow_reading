import 'dart:math' as math;

import 'package:flow_reading/shared/domain/book.dart';
import 'package:flutter/material.dart';

enum ReaderTheme { light, dark, paper }

enum ReaderFont { serif, sans, monospace }

class ReaderSettings {
  const ReaderSettings({
    this.font = ReaderFont.serif,
    this.fontSize = 18,
    this.lineHeight = 1.55,
    this.horizontalMargin = 24,
    this.theme = ReaderTheme.paper,
  });

  final ReaderFont font;
  final double fontSize;
  final double lineHeight;
  final double horizontalMargin;
  final ReaderTheme theme;

  String? get fontFamily => switch (font) {
    ReaderFont.serif => 'serif',
    ReaderFont.sans => null,
    ReaderFont.monospace => 'monospace',
  };

  ReaderSettings copyWith({
    ReaderFont? font,
    double? fontSize,
    double? lineHeight,
    double? horizontalMargin,
    ReaderTheme? theme,
  }) => ReaderSettings(
    font: font ?? this.font,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    horizontalMargin: horizontalMargin ?? this.horizontalMargin,
    theme: theme ?? this.theme,
  );
}

class PageSlice {
  const PageSlice({
    required this.chapter,
    required this.block,
    this.start = 0,
    this.end = 0,
    this.estimatedHeight = 0,
  });

  final Chapter chapter;
  final ContentBlock block;
  final int start;
  final int end;
  final double estimatedHeight;

  String get contentId => block.paragraph?.id ?? block.image!.id;
  String get text => block.paragraph?.text.substring(start, end) ?? '';
}

class ReaderPage {
  const ReaderPage({required this.slices});
  final List<PageSlice> slices;

  ReadingLocator locator(String bookId) {
    final first = slices.first;
    return ReadingLocator(
      bookId: bookId,
      contentId: first.contentId,
      characterOffset: first.start,
    );
  }
}

class PaginationResult {
  const PaginationResult(this.pages);
  final List<ReaderPage> pages;

  int pageFor(ReadingLocator locator, Book book) {
    final normalized = normalizeLocator(book, locator);
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      for (final slice in pages[pageIndex].slices) {
        if (slice.contentId == normalized.contentId &&
            normalized.characterOffset >= slice.start &&
            normalized.characterOffset <= slice.end) {
          return pageIndex;
        }
      }
    }
    return 0;
  }
}

class PaginationEngine {
  const PaginationEngine();

  PaginationResult paginate({
    required Book book,
    required Size viewport,
    required ReaderSettings settings,
  }) {
    final width = math.max(
      120.0,
      viewport.width - settings.horizontalMargin * 2,
    );
    final height = math.max(160.0, viewport.height - 24);
    final pages = <ReaderPage>[];
    var current = <PageSlice>[];
    var used = 0.0;

    void finishPage() {
      if (current.isEmpty) return;
      pages.add(ReaderPage(slices: List.unmodifiable(current)));
      current = [];
      used = 0;
    }

    for (final chapter in book.chapters) {
      for (final block in chapter.blocks) {
        if (block.image != null) {
          final imageHeight = math.min(height, math.max(180.0, height * .58));
          if (current.isNotEmpty && used + imageHeight > height) finishPage();
          current.add(
            PageSlice(
              chapter: chapter,
              block: block,
              estimatedHeight: imageHeight,
            ),
          );
          used += imageHeight + 12;
          continue;
        }
        final paragraph = block.paragraph;
        if (paragraph == null || paragraph.text.trim().isEmpty) continue;
        var offset = 0;
        while (offset < paragraph.text.length) {
          final style = textStyleFor(block.kind, settings);
          final remaining = height - used - 10;
          if (remaining < style.fontSize! * style.height! * 1.4 &&
              current.isNotEmpty) {
            finishPage();
            continue;
          }
          var end = _fitEnd(
            paragraph.text,
            offset,
            width,
            math.max(40, height - used - 10),
            style,
            _directionFor(paragraph.text),
          );
          if (end <= offset) {
            if (current.isNotEmpty) {
              finishPage();
              continue;
            }
            end = math.min(paragraph.text.length, offset + 1);
          }
          if (end < paragraph.text.length) {
            final whitespace = paragraph.text.lastIndexOf(
              RegExp(r'\s'),
              end - 1,
            );
            if (whitespace > offset + 8) end = whitespace + 1;
          }
          final sliceText = paragraph.text.substring(offset, end);
          final measured = _measure(
            sliceText,
            width,
            style,
            _directionFor(sliceText),
          );
          current.add(
            PageSlice(
              chapter: chapter,
              block: block,
              start: offset,
              end: end,
              estimatedHeight: measured,
            ),
          );
          used += measured + 10;
          offset = end;
          if (offset < paragraph.text.length) finishPage();
        }
      }
    }
    finishPage();
    return PaginationResult(
      pages.isEmpty ? const [ReaderPage(slices: [])] : pages,
    );
  }

  static TextStyle textStyleFor(BlockKind kind, ReaderSettings settings) {
    final heading = kind == BlockKind.heading;
    return TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: heading ? settings.fontSize * 1.38 : settings.fontSize,
      height: heading ? 1.28 : settings.lineHeight,
      fontWeight: heading ? FontWeight.w700 : FontWeight.normal,
    );
  }

  int _fitEnd(
    String text,
    int start,
    double width,
    double height,
    TextStyle style,
    TextDirection direction,
  ) {
    var low = start + 1;
    var high = text.length;
    var best = start;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final measured = _measure(
        text.substring(start, middle),
        width,
        style,
        direction,
      );
      if (measured <= height) {
        best = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return best;
  }

  double _measure(
    String text,
    double width,
    TextStyle style,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      maxLines: null,
    )..layout(maxWidth: width);
    return painter.height;
  }

  static TextDirection _directionFor(String text) =>
      RegExp(r'[\u0590-\u08ff]').hasMatch(text)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

ReadingLocator normalizeLocator(Book book, ReadingLocator locator) {
  for (final chapter in book.chapters) {
    for (final block in chapter.blocks) {
      final paragraph = block.paragraph;
      if (paragraph == null) {
        if (block.image?.id == locator.contentId) return locator;
        continue;
      }
      if (paragraph.id == locator.contentId) return locator;
      var sentenceCursor = 0;
      for (final sentence in paragraph.sentences) {
        final sentenceStart = paragraph.text.indexOf(
          sentence.text,
          sentenceCursor,
        );
        final safeSentenceStart = sentenceStart < 0
            ? sentenceCursor
            : sentenceStart;
        if (sentence.id == locator.contentId) {
          return ReadingLocator(
            bookId: locator.bookId,
            contentId: paragraph.id,
            characterOffset: safeSentenceStart + locator.characterOffset,
            wordOffset: locator.wordOffset,
            affinity: locator.affinity,
          );
        }
        for (final word in sentence.words) {
          if (word.id == locator.contentId) {
            return ReadingLocator(
              bookId: locator.bookId,
              contentId: paragraph.id,
              characterOffset:
                  safeSentenceStart + word.start + locator.characterOffset,
              wordOffset: locator.wordOffset,
              affinity: locator.affinity,
            );
          }
        }
        sentenceCursor = safeSentenceStart + sentence.text.length;
      }
    }
  }
  return locator;
}
