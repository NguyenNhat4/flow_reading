import 'dart:convert';

import 'package:flow_reading/domain/models/ai_cache_entry.dart';
import 'package:flow_reading/domain/models/ai_provider_models.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/book_search.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/repositories/ai_artifact_repository.dart';
import 'package:flow_reading/domain/repositories/ai_credential_repository.dart';
import 'package:flow_reading/domain/repositories/ai_provider.dart';
import 'package:flow_reading/domain/repositories/book_search_repository.dart';
import 'package:flow_reading/domain/use_cases/build_ai_context.dart';
import 'package:flow_reading/domain/use_cases/generate_grammar_explanation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requests only passage-relevant grammar with exact evidence', () async {
    final artifacts = _Artifacts();
    final provider = _Provider();
    final useCase = _useCase(artifacts, provider);

    final result = await useCase(
      chapters: _chapters,
      selection: _selection,
      currentPosition: _position,
    );

    expect(result.explanation.points, hasLength(1));
    expect(result.explanation.points.single.evidence, 'Having finished');
    expect(result.explanation.points.single.relevance, contains('before'));
    expect(
      provider.requests.single.instructions,
      allOf(
        contains('only grammar that is necessary'),
        contains('Quote the exact evidence'),
        contains('generic grammar lesson'),
      ),
    );
    expect(artifacts.saved, hasLength(1));
  });

  test('reuses the cached grammar result without another request', () async {
    final artifacts = _Artifacts();
    final provider = _Provider();
    final useCase = _useCase(artifacts, provider);
    await useCase(
      chapters: _chapters,
      selection: _selection,
      currentPosition: _position,
    );

    final result = await useCase(
      chapters: _chapters,
      selection: _selection,
      currentPosition: _position,
    );

    expect(result.fromCache, isTrue);
    expect(provider.requests, hasLength(1));
  });
}

GenerateGrammarExplanationUseCase _useCase(
  _Artifacts artifacts,
  _Provider provider,
) => GenerateGrammarExplanationUseCase(
  contextBuilder: BuildAiContextUseCase(
    searchRepository: const _SearchRepository(),
  ),
  artifactRepository: artifacts,
  credentialRepository: const _Credentials(),
  provider: provider,
  model: 'gpt-5.6-luna',
);

const _response = <String, Object?>{
  'points': [
    {
      'feature': 'Perfect participle clause',
      'evidence': 'Having finished',
      'explanation':
          'The clause marks the finishing as completed before the main action.',
      'relevance':
          'It makes clear that finishing happened before she closed the book.',
    },
  ],
  'interpretations': <String>[],
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
  const _Credentials();

  @override
  Future<bool> contains(String providerId) async => true;

  @override
  Future<void> delete(String providerId) async {}

  @override
  Future<String?> read(String providerId) async => 'key';

  @override
  Future<void> write({
    required String providerId,
    required String apiKey,
  }) async {}
}

final class _Provider implements AiProvider {
  final requests = <AiProviderRequest>[];

  @override
  String get id => 'openai';

  @override
  Future<AiCompletion> complete({
    required String apiKey,
    required AiProviderRequest request,
  }) async {
    requests.add(request);
    return AiCompletion(
      text: jsonEncode(_response),
      providerId: id,
      model: request.model,
    );
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

const _text = 'Having finished, she closed the book.';

final _chapters = [
  Chapter(
    id: 'chapter',
    bookId: 'book',
    title: 'Evening',
    order: 0,
    blocks: [
      ParagraphBlock(
        id: 'block',
        chapterId: 'chapter',
        order: 0,
        spans: const [InlineTextSpan(text: _text)],
      ),
    ],
  ),
];

final _selection = PassageSelection(
  anchor: TextAnchor(
    bookId: 'book',
    chapterId: 'chapter',
    blockId: 'block',
    startOffset: 0,
    endOffset: _text.length,
  ),
  textSnapshot: _text,
);

final _position = ReadingLocator(anchor: _selection.anchor);
