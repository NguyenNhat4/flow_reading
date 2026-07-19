import 'package:flow_reading/domain/models/ai_context.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/book_search.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/book_search_repository.dart';
import 'package:flow_reading/domain/use_cases/build_ai_context.dart';
import 'package:flow_reading/domain/use_cases/sentence_segmenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BuildAiContextUseCase', () {
    test('builds anchored local, earlier, and conversation context', () async {
      final search = _SearchRepository([
        _result(
          chapterId: 'chapter-1',
          blockId: 'earlier',
          text: 'Earlier explorers studied the mysterious river.',
        ),
        _result(
          chapterId: 'chapter-2',
          blockId: 'after',
          text: 'A later block must not be included as earlier context.',
        ),
      ]);
      final useCase = BuildAiContextUseCase(searchRepository: search);
      final selection = TextAnchor(
        bookId: 'book',
        chapterId: 'chapter-2',
        blockId: 'selected',
        startOffset: 4,
        endOffset: 14,
      );

      final context = await useCase.build(
        chapters: _chapters,
        selection: selection,
        selectedText: 'mysterious',
        currentPosition: ReadingLocator(
          anchor: TextAnchor(
            bookId: 'book',
            chapterId: 'chapter-2',
            blockId: 'selected',
            startOffset: 0,
            endOffset: 0,
          ),
        ),
        recentMessages: [
          AiContextMessage(
            role: AiContextMessageRole.user,
            text: 'What is happening here?',
            referencedRanges: [selection],
          ),
          AiContextMessage(
            role: AiContextMessageRole.assistant,
            text: 'The scene introduces uncertainty.',
          ),
        ],
      );

      expect(context.chapterTitle, 'Current chapter');
      expect(context.currentPosition.anchor.blockId, 'selected');
      expect(context.selectedPassage.text, 'mysterious');
      expect(
        context.passages
            .where(
              (passage) =>
                  passage.roles.contains(AiContextRole.containingSentence),
            )
            .single
            .text,
        'The mysterious river moved quietly. ',
      );
      expect(
        context.passages
            .where(
              (passage) =>
                  passage.roles.contains(AiContextRole.nearbyParagraph),
            )
            .map((passage) => passage.anchor.blockId),
        containsAll(['before', 'after']),
      );
      final earlier = context.passages.where(
        (passage) =>
            passage.roles.contains(AiContextRole.relevantEarlierPassage),
      );
      expect(earlier.map((passage) => passage.anchor.blockId), ['earlier']);
      expect(earlier.single.anchor.endOffset, earlier.single.text.length);
      expect(context.recentMessages.map((message) => message.role), [
        AiContextMessageRole.user,
        AiContextMessageRole.assistant,
      ]);
      expect(context.characterCount, lessThanOrEqualTo(12000));
    });

    test(
      'keeps selected text first and merges exact duplicate roles',
      () async {
        const text = 'Whole sentence.';
        final chapter = Chapter(
          id: 'chapter',
          bookId: 'book',
          title: 'Title',
          order: 0,
          blocks: [
            ParagraphBlock(
              id: 'block',
              chapterId: 'chapter',
              order: 0,
              spans: const [InlineTextSpan(text: text)],
              sentences: SentenceSegmenter.segment(
                blockId: 'block',
                text: text,
              ),
            ),
          ],
        );
        final anchor = TextAnchor(
          bookId: 'book',
          chapterId: 'chapter',
          blockId: 'block',
          startOffset: 0,
          endOffset: text.length,
        );

        final context =
            await BuildAiContextUseCase(
              searchRepository: const _SearchRepository([]),
            ).build(
              chapters: [chapter],
              selection: anchor,
              selectedText: text,
              currentPosition: ReadingLocator(
                anchor: TextAnchor(
                  bookId: 'book',
                  chapterId: 'chapter',
                  blockId: 'block',
                  startOffset: 0,
                  endOffset: 0,
                ),
              ),
            );

        expect(context.passages, hasLength(1));
        expect(context.passages.single.roles, {
          AiContextRole.selectedText,
          AiContextRole.containingSentence,
          AiContextRole.containingParagraph,
        });
      },
    );

    test(
      'respects a small budget and truncates optional anchored text',
      () async {
        final selected = TextAnchor(
          bookId: 'book',
          chapterId: 'chapter-2',
          blockId: 'selected',
          startOffset: 4,
          endOffset: 14,
        );

        final context =
            await BuildAiContextUseCase(
              searchRepository: const _SearchRepository([]),
            ).build(
              chapters: _chapters,
              selection: selected,
              selectedText: 'mysterious',
              currentPosition: ReadingLocator(
                anchor: TextAnchor(
                  bookId: 'book',
                  chapterId: 'chapter-2',
                  blockId: 'selected',
                  startOffset: 0,
                  endOffset: 0,
                ),
              ),
              maxCharacters: 145,
            );

        expect(context.characterCount, lessThanOrEqualTo(145));
        expect(context.passages.first.anchor.id, selected.id);
        for (final passage in context.passages) {
          expect(
            passage.anchor.endOffset - passage.anchor.startOffset,
            passage.text.length,
          );
        }
      },
    );

    test(
      'retains only the six most recent messages in chronological order',
      () async {
        final messages = [
          for (var index = 0; index < 8; index++)
            AiContextMessage(
              role: AiContextMessageRole.user,
              text: 'message-$index',
            ),
        ];

        final context =
            await BuildAiContextUseCase(
              searchRepository: const _SearchRepository([]),
            ).build(
              chapters: _chapters,
              selection: _selection,
              selectedText: 'mysterious',
              currentPosition: ReadingLocator(
                anchor: TextAnchor(
                  bookId: 'book',
                  chapterId: 'chapter-2',
                  blockId: 'selected',
                  startOffset: 0,
                  endOffset: 0,
                ),
              ),
              recentMessages: messages,
            );

        expect(context.recentMessages.map((message) => message.text), [
          'message-2',
          'message-3',
          'message-4',
          'message-5',
          'message-6',
          'message-7',
        ]);
      },
    );

    test(
      'rejects selections that cannot fit or mismatch canonical text',
      () async {
        final useCase = BuildAiContextUseCase(
          searchRepository: const _SearchRepository([]),
        );

        await expectLater(
          useCase.build(
            chapters: _chapters,
            selection: _selection,
            selectedText: 'mysterious',
            currentPosition: ReadingLocator(
              anchor: TextAnchor(
                bookId: 'book',
                chapterId: 'chapter-2',
                blockId: 'selected',
                startOffset: 0,
                endOffset: 0,
              ),
            ),
            maxCharacters: 5,
          ),
          throwsA(isA<AiContextLimitFailure>()),
        );
        await expectLater(
          useCase.build(
            chapters: _chapters,
            selection: _selection,
            selectedText: 'different',
            currentPosition: ReadingLocator(
              anchor: TextAnchor(
                bookId: 'book',
                chapterId: 'chapter-2',
                blockId: 'selected',
                startOffset: 0,
                endOffset: 0,
              ),
            ),
          ),
          throwsArgumentError,
        );
      },
    );
  });
}

final _selection = TextAnchor(
  bookId: 'book',
  chapterId: 'chapter-2',
  blockId: 'selected',
  startOffset: 4,
  endOffset: 14,
);

final _chapters = <Chapter>[
  const Chapter(
    id: 'chapter-1',
    bookId: 'book',
    title: 'Earlier chapter',
    order: 0,
    blocks: [
      ParagraphBlock(
        id: 'earlier',
        chapterId: 'chapter-1',
        order: 0,
        spans: [
          InlineTextSpan(
            text: 'Earlier explorers studied the mysterious river.',
          ),
        ],
      ),
    ],
  ),
  Chapter(
    id: 'chapter-2',
    bookId: 'book',
    title: 'Current chapter',
    order: 1,
    blocks: [
      const ParagraphBlock(
        id: 'before',
        chapterId: 'chapter-2',
        order: 0,
        spans: [InlineTextSpan(text: 'Nearby context before the selection.')],
      ),
      ParagraphBlock(
        id: 'selected',
        chapterId: 'chapter-2',
        order: 1,
        spans: const [
          InlineTextSpan(
            text: 'The mysterious river moved quietly. Another sentence.',
          ),
        ],
        sentences: SentenceSegmenter.segment(
          blockId: 'selected',
          text: 'The mysterious river moved quietly. Another sentence.',
        ),
      ),
      const ParagraphBlock(
        id: 'after',
        chapterId: 'chapter-2',
        order: 2,
        spans: [InlineTextSpan(text: 'Nearby context after the selection.')],
      ),
    ],
  ),
];

BookSearchResult _result({
  required String chapterId,
  required String blockId,
  required String text,
}) => BookSearchResult(
  segment: SearchableSegment(
    segmentId: blockId,
    bookId: 'book',
    chapterId: chapterId,
    blockId: blockId,
    plainText: text,
  ),
  excerpt: text,
  locator: ReadingLocator(
    anchor: TextAnchor(
      bookId: 'book',
      chapterId: chapterId,
      blockId: blockId,
      startOffset: 0,
      endOffset: 0,
    ),
  ),
);

final class _SearchRepository implements BookSearchRepository {
  const _SearchRepository(this.results);

  final List<BookSearchResult> results;

  @override
  Future<List<BookSearchResult>> search({
    required String bookId,
    required String query,
    int limit = 50,
  }) async => results
      .where(
        (result) =>
            result.segment.bookId == bookId &&
            result.segment.plainText.toLowerCase().contains(
              query.toLowerCase(),
            ),
      )
      .take(limit)
      .toList();
}
