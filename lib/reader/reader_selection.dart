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
  if (sourceOffset < 0 || sourceOffset >= sourceText.length) return null;
  for (final match in _wordPattern.allMatches(sourceText)) {
    if (sourceOffset < match.start) return null;
    if (sourceOffset >= match.end) continue;
    return WordSelection(
      anchor: TextAnchor(
        bookId: bookId,
        chapterId: chapterId,
        blockId: blockId,
        startOffset: match.start,
        endOffset: match.end,
      ),
      textSnapshot: match.group(0)!,
    );
  }
  return null;
}
