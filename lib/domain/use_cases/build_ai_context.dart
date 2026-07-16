import 'package:flow_reading/domain/models/ai_context.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/book_search.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/book_search_repository.dart';
import 'package:flow_reading/domain/use_cases/sentence_segmenter.dart';

/// Builds bounded AI context from canonical book content and stable anchors.
final class BuildAiContextUseCase {
  factory BuildAiContextUseCase({
    required BookSearchRepository searchRepository,
    int defaultMaxCharacters = 12000,
  }) => BuildAiContextUseCase._(searchRepository, defaultMaxCharacters);

  const BuildAiContextUseCase._(
    this._searchRepository,
    this.defaultMaxCharacters,
  );

  final BookSearchRepository _searchRepository;
  final int defaultMaxCharacters;

  Future<AiContextPackage> build({
    required List<Chapter> chapters,
    required TextAnchor selection,
    required String selectedText,
    required ReadingLocator currentPosition,
    List<AiContextMessage> recentMessages = const [],
    int? maxCharacters,
  }) async {
    final budget = maxCharacters ?? defaultMaxCharacters;
    if (budget <= 0) {
      throw ArgumentError.value(budget, 'maxCharacters', 'Must be positive');
    }
    final orderedChapters = [...chapters]
      ..sort((left, right) => left.order.compareTo(right.order));
    final chapter = orderedChapters
        .where((candidate) => candidate.id == selection.chapterId)
        .firstOrNull;
    if (chapter == null || chapter.bookId != selection.bookId) {
      throw ArgumentError('Selection does not belong to the supplied book');
    }
    if (currentPosition.anchor.bookId != selection.bookId) {
      throw ArgumentError('Current position belongs to another book');
    }
    final blocks = [...chapter.blocks]
      ..sort((left, right) => left.order.compareTo(right.order));
    final blockIndex = blocks.indexWhere(
      (block) => block.id == selection.blockId,
    );
    if (blockIndex < 0) {
      throw ArgumentError('Selection block is not available');
    }
    final block = blocks[blockIndex];
    final blockText = _plainText(block);
    if (blockText == null ||
        selection.startOffset < 0 ||
        selection.endOffset > blockText.length ||
        selection.endOffset <= selection.startOffset ||
        blockText.substring(selection.startOffset, selection.endOffset) !=
            selectedText) {
      throw ArgumentError('Selection text does not match canonical content');
    }

    final fixedCharacters = chapter.title.length + selectedText.length;
    if (fixedCharacters > budget) throw const AiContextLimitFailure();
    final accumulator = _ContextAccumulator(
      maxCharacters: budget,
      chapterTitle: chapter.title,
    );
    accumulator.addRequired(
      AiContextPassage(
        anchor: selection,
        text: selectedText,
        roles: const {AiContextRole.selectedText},
      ),
    );

    final sentence = _containingSentence(
      block: block,
      blockText: blockText,
      selection: selection,
    );
    if (sentence != null) accumulator.addOptional(sentence);
    accumulator.addOptional(
      AiContextPassage(
        anchor: TextAnchor(
          bookId: selection.bookId,
          chapterId: selection.chapterId,
          blockId: selection.blockId,
          startOffset: 0,
          endOffset: blockText.length,
        ),
        text: blockText,
        roles: const {AiContextRole.containingParagraph},
      ),
    );

    final nearby = _nearbyPassages(
      blocks: blocks,
      selectedBlockIndex: blockIndex,
      selection: selection,
    );
    for (final passage in nearby) {
      accumulator.addOptional(passage, allowTruncation: true);
    }

    final earlier = await _relevantEarlierPassages(
      orderedChapters: orderedChapters,
      selection: selection,
      sourceText: sentence?.text ?? selectedText,
    );
    for (final passage in earlier) {
      accumulator.addOptional(passage, allowTruncation: true);
    }

    final retainedMessages = <AiContextMessage>[];
    for (final message in recentMessages.reversed.take(6)) {
      final remaining =
          accumulator.remainingCharacters -
          retainedMessages.fold<int>(
            0,
            (sum, retained) => sum + retained.text.length,
          );
      if (remaining <= 0) break;
      final text = message.text.length <= remaining
          ? message.text
          : _safePrefix(message.text, remaining);
      if (text.trim().isEmpty) continue;
      retainedMessages.add(
        AiContextMessage(
          role: message.role,
          text: text,
          referencedRanges: message.referencedRanges,
        ),
      );
    }

    return AiContextPackage(
      chapterTitle: chapter.title,
      currentPosition: currentPosition,
      passages: accumulator.passages,
      recentMessages: retainedMessages.reversed.toList(),
      maxCharacters: budget,
    );
  }

  Future<List<AiContextPassage>> _relevantEarlierPassages({
    required List<Chapter> orderedChapters,
    required TextAnchor selection,
    required String sourceText,
  }) async {
    final terms = _searchTerms(sourceText);
    if (terms.isEmpty) return const [];
    final resultsByTerm = await Future.wait([
      for (final term in terms)
        _searchRepository.search(
          bookId: selection.bookId,
          query: term,
          limit: 50,
        ),
    ]);
    final order = _blockOrder(orderedChapters);
    final selectedOrder =
        order[_blockKey(selection.chapterId, selection.blockId)];
    if (selectedOrder == null) return const [];
    final candidates = <String, _EarlierCandidate>{};
    for (var termIndex = 0; termIndex < terms.length; termIndex++) {
      for (final result in resultsByTerm[termIndex]) {
        final segment = result.segment;
        final candidateOrder =
            order[_blockKey(segment.chapterId, segment.blockId)];
        if (candidateOrder == null || candidateOrder >= selectedOrder) continue;
        final candidate = candidates.putIfAbsent(
          segment.blockId,
          () => _EarlierCandidate(segment: segment, order: candidateOrder),
        );
        candidate.matchedTerms.add(terms[termIndex]);
      }
    }
    final ranked = candidates.values.toList()
      ..sort((left, right) {
        final relevance = right.matchedTerms.length.compareTo(
          left.matchedTerms.length,
        );
        if (relevance != 0) return relevance;
        return right.order.compareTo(left.order);
      });
    return [
      for (final candidate in ranked.take(3))
        AiContextPassage(
          anchor: TextAnchor(
            bookId: candidate.segment.bookId,
            chapterId: candidate.segment.chapterId,
            blockId: candidate.segment.blockId,
            startOffset: 0,
            endOffset: candidate.segment.plainText.length,
          ),
          text: candidate.segment.plainText,
          roles: const {AiContextRole.relevantEarlierPassage},
        ),
    ];
  }

  static AiContextPassage? _containingSentence({
    required ContentBlock block,
    required String blockText,
    required TextAnchor selection,
  }) {
    final sentences = switch (block) {
      ParagraphBlock(:final sentences) when sentences.isNotEmpty => sentences,
      _ => SentenceSegmenter.segment(blockId: block.id, text: blockText),
    };
    final sentence = sentences
        .where(
          (candidate) =>
              candidate.startOffset < selection.endOffset &&
              candidate.endOffset > selection.startOffset,
        )
        .firstOrNull;
    if (sentence == null) return null;
    return AiContextPassage(
      anchor: TextAnchor(
        bookId: selection.bookId,
        chapterId: selection.chapterId,
        blockId: selection.blockId,
        startOffset: sentence.startOffset,
        endOffset: sentence.endOffset,
      ),
      text: blockText.substring(sentence.startOffset, sentence.endOffset),
      roles: const {AiContextRole.containingSentence},
    );
  }

  static List<AiContextPassage> _nearbyPassages({
    required List<ContentBlock> blocks,
    required int selectedBlockIndex,
    required TextAnchor selection,
  }) {
    final passages = <AiContextPassage>[];
    var before = 0;
    var after = 0;
    for (var distance = 1; distance < blocks.length; distance++) {
      final previousIndex = selectedBlockIndex - distance;
      if (before < 2 && previousIndex >= 0) {
        final passage = _blockPassage(
          block: blocks[previousIndex],
          selection: selection,
        );
        if (passage != null) {
          passages.add(passage);
          before++;
        }
      }
      final nextIndex = selectedBlockIndex + distance;
      if (after < 2 && nextIndex < blocks.length) {
        final passage = _blockPassage(
          block: blocks[nextIndex],
          selection: selection,
        );
        if (passage != null) {
          passages.add(passage);
          after++;
        }
      }
      if ((before >= 2 || previousIndex < 0) &&
          (after >= 2 || nextIndex >= blocks.length)) {
        break;
      }
    }
    return passages;
  }

  static AiContextPassage? _blockPassage({
    required ContentBlock block,
    required TextAnchor selection,
  }) {
    final text = _plainText(block);
    if (text == null || text.trim().isEmpty) return null;
    return AiContextPassage(
      anchor: TextAnchor(
        bookId: selection.bookId,
        chapterId: selection.chapterId,
        blockId: block.id,
        startOffset: 0,
        endOffset: text.length,
      ),
      text: text,
      roles: const {AiContextRole.nearbyParagraph},
    );
  }

  static Map<String, int> _blockOrder(List<Chapter> chapters) {
    final order = <String, int>{};
    var index = 0;
    for (final chapter in chapters) {
      final blocks = [...chapter.blocks]
        ..sort((left, right) => left.order.compareTo(right.order));
      for (final block in blocks) {
        order[_blockKey(chapter.id, block.id)] = index++;
      }
    }
    return order;
  }

  static List<String> _searchTerms(String source) {
    final unique = <String>{};
    for (final match in RegExp(
      r"[\p{L}\p{N}\p{M}_]+(?:['’\-][\p{L}\p{N}\p{M}_]+)*",
      unicode: true,
    ).allMatches(source)) {
      final term = match.group(0)!.toLowerCase();
      if (term.length >= 3) unique.add(term);
    }
    final terms = unique.toList()
      ..sort((left, right) {
        final length = right.length.compareTo(left.length);
        return length != 0 ? length : left.compareTo(right);
      });
    return terms.take(4).toList(growable: false);
  }
}

final class _ContextAccumulator {
  _ContextAccumulator({required this.maxCharacters, required this.chapterTitle})
    : _characterCount = chapterTitle.length;

  final int maxCharacters;
  final String chapterTitle;
  final List<AiContextPassage> passages = [];
  final Map<String, int> _passageByText = {};
  int _characterCount;

  int get remainingCharacters => maxCharacters - _characterCount;

  void addRequired(AiContextPassage passage) {
    if (!_add(passage)) throw const AiContextLimitFailure();
  }

  void addOptional(AiContextPassage passage, {bool allowTruncation = false}) {
    if (_add(passage)) return;
    if (!allowTruncation || remainingCharacters < 80) return;
    final text = _safePrefix(passage.text, remainingCharacters);
    if (text.trim().isEmpty) return;
    _add(
      AiContextPassage(
        anchor: TextAnchor(
          bookId: passage.anchor.bookId,
          chapterId: passage.anchor.chapterId,
          blockId: passage.anchor.blockId,
          startOffset: passage.anchor.startOffset,
          endOffset: passage.anchor.startOffset + text.length,
        ),
        text: text,
        roles: passage.roles,
      ),
    );
  }

  bool _add(AiContextPassage passage) {
    final normalized = passage.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return true;
    final duplicate = _passageByText[normalized];
    if (duplicate != null) {
      passages[duplicate] = passages[duplicate].withRoles(passage.roles);
      return true;
    }
    if (passage.text.length > remainingCharacters) return false;
    _passageByText[normalized] = passages.length;
    passages.add(passage);
    _characterCount += passage.text.length;
    return true;
  }
}

final class _EarlierCandidate {
  _EarlierCandidate({required this.segment, required this.order});

  final SearchableSegment segment;
  final int order;
  final Set<String> matchedTerms = {};
}

String _blockKey(String chapterId, String blockId) => '$chapterId::$blockId';

String? _plainText(ContentBlock block) => switch (block) {
  ParagraphBlock() => block.text,
  HeadingBlock() => block.text,
  QuoteBlock() => block.text,
  ListBlock() => block.items.map(_listItemText).join('\n'),
  ImageBlock() => null,
};

String _listItemText(BookListItem item) =>
    [item.text, ...item.children.map(_listItemText)].join('\n');

String _safePrefix(String text, int maximumLength) {
  if (maximumLength <= 0) return '';
  var end = maximumLength.clamp(0, text.length);
  if (end < text.length &&
      end > 0 &&
      _isLowSurrogate(text.codeUnitAt(end)) &&
      _isHighSurrogate(text.codeUnitAt(end - 1))) {
    end--;
  }
  if (end < text.length) {
    final boundary = text
        .substring(0, end)
        .lastIndexOf(RegExp(r'[.!?\n]\s*', unicode: true));
    if (boundary >= 79) end = boundary + 1;
  }
  return text.substring(0, end);
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;
