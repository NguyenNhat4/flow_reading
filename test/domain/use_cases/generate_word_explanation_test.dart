import 'dart:convert';

import 'package:flow_reading/domain/models/ai_cache_entry.dart';
import 'package:flow_reading/domain/models/ai_provider_models.dart';
import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/book_search.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/ai_artifact_repository.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:flow_reading/domain/repositories/book_search_repository.dart';
import 'package:flow_reading/domain/use_cases/build_ai_context.dart';
import 'package:flow_reading/domain/use_cases/generate_word_explanation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenerateWordExplanationUseCase', () {
    test('grounds the request in the sentence and caches the result', () async {
      final artifacts = _Artifacts();
      final provider = _Provider();
      final credentials = _Credentials('secret');
      final useCase = _useCase(
        artifacts: artifacts,
        provider: provider,
        credentials: credentials,
      );

      final result = await useCase(
        chapters: _chapters,
        selection: _selection,
        currentPosition: _position,
      );

      expect(result.fromCache, isFalse);
      expect(
        result.explanation.description,
        'Động từ chỉ hành động đọc chữ viết.',
      );
      expect(
        result.explanation.contextualMeaning,
        'Trong câu này, từ này có nghĩa là đọc nội dung.',
      );
      expect(result.explanation.examples, hasLength(2));
      expect(artifacts.saved, hasLength(1));
      final requestInput = (jsonDecode(provider.requests.single.input) as Map)
          .cast<String, Object?>();
      final context = (requestInput['context'] as Map).cast<String, Object?>();
      final passages = (context['passages'] as List<Object?>)
          .whereType<Map>()
          .map((passage) => passage.cast<String, Object?>())
          .toList();
      expect(
        passages,
        contains(
          predicate<Map<String, Object?>>(
            (passage) =>
                passage['text'] == 'Read locally.' &&
                (passage['roles'] as List<Object?>).contains(
                  'containingSentence',
                ),
          ),
        ),
      );
    });

    test('reuses a cached result without a key or provider request', () async {
      final artifacts = _Artifacts();
      final provider = _Provider();
      final first = _useCase(
        artifacts: artifacts,
        provider: provider,
        credentials: _Credentials('secret'),
      );
      await first(
        chapters: _chapters,
        selection: _selection,
        currentPosition: _position,
      );
      final second = _useCase(
        artifacts: artifacts,
        provider: provider,
        credentials: _Credentials(null),
      );

      final result = await second(
        chapters: _chapters,
        selection: _selection,
        currentPosition: _position,
      );

      expect(result.fromCache, isTrue);
      expect(provider.requests, hasLength(1));
    });

    test('does not cache malformed provider output', () async {
      final artifacts = _Artifacts();
      final useCase = _useCase(
        artifacts: artifacts,
        provider: _Provider(
          response: jsonEncode({
            ..._response,
            'examples': ['Only one'],
          }),
        ),
        credentials: _Credentials('secret'),
      );

      await expectLater(
        useCase(
          chapters: _chapters,
          selection: _selection,
          currentPosition: _position,
        ),
        throwsFormatException,
      );
      expect(artifacts.saved, isEmpty);
    });

    test('requires a configured key after a cache miss', () async {
      final useCase = _useCase(
        artifacts: _Artifacts(),
        provider: _Provider(),
        credentials: _Credentials(null),
      );

      await expectLater(
        useCase(
          chapters: _chapters,
          selection: _selection,
          currentPosition: _position,
        ),
        throwsA(isA<AiNotConfiguredFailure>()),
      );
    });
  });
}

GenerateWordExplanationUseCase _useCase({
  required _Artifacts artifacts,
  required _Provider provider,
  required _Credentials credentials,
}) => GenerateWordExplanationUseCase(
  contextBuilder: BuildAiContextUseCase(
    searchRepository: const _SearchRepository(),
  ),
  artifactRepository: artifacts,
  credentialRepository: credentials,
  provider: provider,
  model: 'gpt-5.6-luna',
);

const _response = <String, Object?>{
  'description': 'Động từ chỉ hành động đọc chữ viết.',
  'contextualMeaning': 'Trong câu này, từ này có nghĩa là đọc nội dung.',
  'examples': ['Read the next page.', 'She reads every evening.'],
};

final class _Artifacts implements AiArtifactRepository {
  final entries = <String, AiCacheEntry>{};
  final saved = <AiCacheEntry>[];

  @override
  Future<AiCacheEntry?> read(String cacheId) async => entries[cacheId];

  @override
  Future<void> save(AiCacheEntry entry) async {
    entries[entry.id] = entry;
    saved.add(entry);
  }
}

final class _Credentials implements AiCredentialRepository {
  _Credentials(this.key);

  String? key;

  @override
  Future<bool> contains(String providerId) async => key != null;

  @override
  Future<void> delete(String providerId) async => key = null;

  @override
  Future<String?> read(String providerId) async => key;

  @override
  Future<void> write({
    required String providerId,
    required String apiKey,
  }) async => key = apiKey;
}

final class _Provider implements AiProvider {
  _Provider({String? response}) : response = response ?? jsonEncode(_response);

  final String response;
  final requests = <AiProviderRequest>[];

  @override
  String get id => 'openai';

  @override
  Future<AiCompletion> complete({
    required String apiKey,
    required AiProviderRequest request,
  }) async {
    requests.add(request);
    return AiCompletion(text: response, providerId: id, model: request.model);
  }

  @override
  AiStreamOperation stream({
    required String apiKey,
    required AiProviderRequest request,
  }) => throw UnimplementedError();

  @override
  Future<void> validateKey(String apiKey) async {}
}

final class _SearchRepository implements BookSearchRepository {
  const _SearchRepository();

  @override
  Future<List<BookSearchResult>> search({
    required String bookId,
    required String query,
    int limit = 50,
  }) async => const [];
}

final _chapters = [
  Chapter(
    id: 'chapter',
    bookId: 'book',
    title: 'Opening',
    order: 0,
    blocks: [
      ParagraphBlock(
        id: 'block',
        chapterId: 'chapter',
        order: 0,
        spans: const [
          InlineTextSpan(text: 'Read locally. It keeps your place.'),
        ],
        sentences: const [
          BookSentence(
            id: 'sentence-1',
            blockId: 'block',
            order: 0,
            startOffset: 0,
            endOffset: 13,
            text: 'Read locally.',
          ),
          BookSentence(
            id: 'sentence-2',
            blockId: 'block',
            order: 1,
            startOffset: 14,
            endOffset: 34,
            text: 'It keeps your place.',
          ),
        ],
      ),
    ],
  ),
];

final _selection = WordSelection(
  anchor: TextAnchor(
    bookId: 'book',
    chapterId: 'chapter',
    blockId: 'block',
    startOffset: 0,
    endOffset: 4,
  ),
  textSnapshot: 'Read',
);

final _position = ReadingLocator(
  anchor: TextAnchor(
    bookId: 'book',
    chapterId: 'chapter',
    blockId: 'block',
    startOffset: 0,
    endOffset: 0,
  ),
);
