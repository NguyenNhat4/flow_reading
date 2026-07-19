import 'dart:async';
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
import 'package:flow_reading/domain/use_cases/generate_passage_explanation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'streams a meaning-preserving structured result and caches it',
    () async {
      final artifacts = _Artifacts();
      final provider = _Provider([
        _Operation.fromEvents([
          AiStreamCompleted(
            AiCompletion(
              text: jsonEncode(_response),
              providerId: 'openai',
              model: 'gpt-5.6-luna',
            ),
          ),
        ]),
      ]);
      final useCase = _useCase(artifacts, provider);

      final session = await useCase.start(
        chapters: _chapters,
        selection: _selection,
        currentPosition: _position,
      );
      final events = await session.events.toList();

      final completed = events.single as PassageExplanationCompleted;
      expect(
        completed.explanation.explanation,
        'After the rain ended, the wet street reflected light.',
      );
      expect(completed.explanation.explicitFacts, hasLength(1));
      expect(completed.explanation.interpretations, hasLength(1));
      expect(artifacts.saved, hasLength(1));
      expect(
        provider.requests.single.instructions,
        contains('preserving its original meaning'),
      );
    },
  );

  test('cancels the underlying provider stream', () async {
    final operation = _Operation.cancellable();
    final useCase = _useCase(_Artifacts(), _Provider([operation]));
    final session = await useCase.start(
      chapters: _chapters,
      selection: _selection,
      currentPosition: _position,
    );
    final events = session.events.toList();

    await session.cancel();

    expect(operation.cancelled, isTrue);
    expect(await events, [isA<PassageExplanationCancelled>()]);
  });

  test(
    'restores a cached passage explanation without starting a stream',
    () async {
      final artifacts = _Artifacts();
      final provider = _Provider([
        _Operation.fromEvents([
          AiStreamCompleted(
            AiCompletion(
              text: jsonEncode(_response),
              providerId: 'openai',
              model: 'gpt-5.6-luna',
            ),
          ),
        ]),
      ]);
      final useCase = _useCase(artifacts, provider);
      final first = await useCase.start(
        chapters: _chapters,
        selection: _selection,
        currentPosition: _position,
      );
      await first.events.drain<void>();

      final second = await useCase.start(
        chapters: _chapters,
        selection: _selection,
        currentPosition: _position,
      );
      final event = await second.events.single;

      expect((event as PassageExplanationCompleted).fromCache, isTrue);
      expect(provider.requests, hasLength(1));
    },
  );
}

GeneratePassageExplanationUseCase _useCase(
  _Artifacts artifacts,
  _Provider provider,
) => GeneratePassageExplanationUseCase(
  contextBuilder: BuildAiContextUseCase(
    searchRepository: const _SearchRepository(),
  ),
  artifactRepository: artifacts,
  credentialRepository: const _Credentials(),
  provider: provider,
  model: 'gpt-5.6-luna',
);

const _response = <String, Object?>{
  'explanation': 'After the rain ended, the wet street reflected light.',
  'explicitFacts': ['The rain stopped and the street shone.'],
  'interpretations': ['The image may suggest a fresh beginning.'],
  'ambiguityWarning': null,
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
  _Provider(this.operations);

  final List<_Operation> operations;
  final requests = <AiProviderRequest>[];
  var _index = 0;

  @override
  String get id => 'openai';

  @override
  Future<AiCompletion> complete({
    required String apiKey,
    required AiProviderRequest request,
  }) => throw UnimplementedError();

  @override
  AiStreamOperation stream({
    required String apiKey,
    required AiProviderRequest request,
  }) {
    requests.add(request);
    return operations[_index++];
  }

  @override
  Future<void> validateKey(String apiKey) async {}
}

final class _Operation implements AiStreamOperation {
  _Operation._(this.events, this._cancel);

  factory _Operation.fromEvents(List<AiStreamEvent> events) =>
      _Operation._(Stream.fromIterable(events), () async {});

  factory _Operation.cancellable() {
    final controller = StreamController<AiStreamEvent>();
    late _Operation operation;
    operation = _Operation._(controller.stream, () async {
      if (operation.cancelled) return;
      operation.cancelled = true;
      controller.add(const AiStreamCancelled());
      await controller.close();
    });
    return operation;
  }

  @override
  final Stream<AiStreamEvent> events;
  final Future<void> Function() _cancel;
  bool cancelled = false;

  @override
  Future<void> cancel() => _cancel();
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

const _text = 'The rain stopped, and the street shone.';

final _chapters = [
  Chapter(
    id: 'chapter',
    bookId: 'book',
    title: 'After the storm',
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
