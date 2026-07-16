import 'package:flow_reading/books/text_anchors.dart';

final _wordPattern = RegExp(
  r"[\p{L}\p{N}\p{M}_]+(?:['’\-\u2010\u2011][\p{L}\p{N}\p{M}_]+)*",
  unicode: true,
);

/// Resolves the word containing [sourceOffset] to a stable canonical range.
WordSelection? wordSelectionAt({
  required String bookId,
  required String chapterId,
  required String blockId,
  required String sourceText,
  required int sourceOffset,
}) {
  final range = wordRangeAt(sourceText, sourceOffset);
  if (range == null) return null;
  return WordSelection(
    anchor: TextAnchor(
      bookId: bookId,
      chapterId: chapterId,
      blockId: blockId,
      startOffset: range.startOffset,
      endOffset: range.endOffset,
    ),
    textSnapshot: sourceText.substring(range.startOffset, range.endOffset),
  );
}

/// Returns the Unicode-aware word range containing [offset].
({int startOffset, int endOffset})? wordRangeAt(String text, int offset) {
  if (offset < 0 || offset >= text.length) return null;
  for (final match in _wordPattern.allMatches(text)) {
    if (offset < match.start) return null;
    if (offset >= match.end) continue;
    return (startOffset: match.start, endOffset: match.end);
  }
  return null;
}

/// Creates a stable passage from an adjusted canonical half-open range.
PassageSelection? passageSelectionForRange({
  required String bookId,
  required String chapterId,
  required String blockId,
  required String sourceText,
  required int startOffset,
  required int endOffset,
}) {
  if (startOffset < 0 ||
      endOffset <= startOffset ||
      endOffset > sourceText.length) {
    return null;
  }
  return PassageSelection(
    anchor: TextAnchor(
      bookId: bookId,
      chapterId: chapterId,
      blockId: blockId,
      startOffset: startOffset,
      endOffset: endOffset,
    ),
    textSnapshot: sourceText.substring(startOffset, endOffset),
  );
}
