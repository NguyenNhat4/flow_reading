import 'package:flow_reading/domain/models/ai_cache_entry.dart';
import 'package:flow_reading/domain/models/ai_context.dart';
import 'package:flow_reading/domain/models/ai_prompt.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes and restores a deterministic cache entry', () {
    final entry = _entry();

    final restored = AiCacheEntry.fromJson(entry.toJson());

    expect(restored.id, entry.id);
    expect(restored.requestType, AiRequestType.wordExplanation);
    expect(restored.sourceRange?.id, entry.sourceRange?.id);
    expect(restored.response, {'meaning': 'contextual'});
    expect(restored.createdAt.isUtc, isTrue);
  });

  test('cache identity changes for every compatibility input', () {
    final original = _entry();
    final changedPrompt = _entry(promptVersion: 2);
    final changedContent = _entry(contentHash: 'other-content');
    final changedContext = _entry(contextFingerprint: 'other-context');
    final changedModel = _entry(model: 'other-model');

    expect(changedPrompt.id, isNot(original.id));
    expect(changedContent.id, isNot(original.id));
    expect(changedContext.id, isNot(original.id));
    expect(changedModel.id, isNot(original.id));
  });

  test('content and context fingerprints are stable and context-sensitive', () {
    final firstContent = AiCacheFingerprints.content('selected text');
    final secondContent = AiCacheFingerprints.content('selected text');
    final firstContext = AiCacheFingerprints.context(_context('Nearby text'));
    final secondContext = AiCacheFingerprints.context(_context('Nearby text'));
    final changedContext = AiCacheFingerprints.context(
      _context('Different nearby text'),
    );

    expect(firstContent, secondContent);
    expect(firstContext, secondContext);
    expect(changedContext, isNot(firstContext));
  });

  test('rejects chat artifacts and tampered stored IDs', () {
    expect(
      () => AiCacheEntry.create(
        bookId: 'book',
        requestType: AiRequestType.chat,
        sourceRange: null,
        contentHash: 'content',
        contextFingerprint: 'context',
        promptId: 'reader_chat',
        promptVersion: 1,
        response: const {'text': 'answer'},
        provider: 'openai',
        model: 'model',
        createdAt: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
    final json = _entry().toJson()..['id'] = 'tampered';
    expect(() => AiCacheEntry.fromJson(json), throwsFormatException);
  });
}

AiCacheEntry _entry({
  int promptVersion = 1,
  String contentHash = 'content-hash',
  String contextFingerprint = 'context-fingerprint',
  String model = 'gpt-5.6-luna',
}) => AiCacheEntry.create(
  bookId: 'book',
  requestType: AiRequestType.wordExplanation,
  sourceRange: _range,
  contentHash: contentHash,
  contextFingerprint: contextFingerprint,
  promptId: 'word_explanation',
  promptVersion: promptVersion,
  response: const {'meaning': 'contextual'},
  provider: 'openai',
  model: model,
  createdAt: DateTime.utc(2026),
);

final _range = TextAnchor(
  bookId: 'book',
  chapterId: 'chapter',
  blockId: 'block',
  startOffset: 0,
  endOffset: 4,
);

AiContextPackage _context(String nearbyText) => AiContextPackage(
  chapterTitle: 'Chapter',
  currentPosition: ReadingLocator(
    anchor: TextAnchor(
      bookId: 'book',
      chapterId: 'chapter',
      blockId: 'block',
      startOffset: 0,
      endOffset: 0,
    ),
  ),
  passages: [
    AiContextPassage(
      anchor: _range,
      text: 'Word',
      roles: const {AiContextRole.selectedText},
    ),
    AiContextPassage(
      anchor: TextAnchor(
        bookId: 'book',
        chapterId: 'chapter',
        blockId: 'nearby',
        startOffset: 0,
        endOffset: nearbyText.length,
      ),
      text: nearbyText,
      roles: const {AiContextRole.nearbyParagraph},
    ),
  ],
  recentMessages: const [],
  maxCharacters: 1000,
);
