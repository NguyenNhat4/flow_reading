import 'dart:async';
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
import 'package:flow_reading/domain/use_cases/generate_passage_explanation.dart';
import 'package:flow_reading/ui/features/reader/view_models/passage_explanation_view_model.dart';
import 'package:flow_reading/ui/features/reader/views/passage_explanation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the passage visible while loading and supports cancel', (
    tester,
  ) async {
    final operation = _Operation.cancellable();
    await _pumpSheet(tester, _Provider([operation]));
    await tester.pump();

    expect(find.text('“$_text”'), findsOneWidget);
    expect(find.text('Explaining this passage…'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cancel-passage-explanation')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('cancel-passage-explanation')));
    await tester.pumpAndSettle();

    expect(operation.cancelled, isTrue);
    expect(find.text('The explanation was cancelled.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('retry-passage-explanation')),
      findsOneWidget,
    );
    expect(find.text('“$_text”'), findsOneWidget);
  });

  testWidgets('failed requests expose Retry and can complete successfully', (
    tester,
  ) async {
    final provider = _Provider([
      _Operation.fromEvents([const AiStreamFailed(NetworkFailure())]),
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
    await _pumpSheet(tester, provider);
    await tester.pumpAndSettle();

    expect(find.text(const NetworkFailure().message), findsOneWidget);
    final retry = find.byKey(const ValueKey('retry-passage-explanation'));
    tester.widget<FilledButton>(retry).onPressed!();
    await tester.pumpAndSettle();

    expect(provider.requests, hasLength(2));
    expect(find.text('In simpler language'), findsOneWidget);
    expect(find.text(_response['explanation']! as String), findsOneWidget);
  });
}

Future<void> _pumpSheet(WidgetTester tester, _Provider provider) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassageExplanationSheet(
            viewModel: PassageExplanationViewModel(
              generate: GeneratePassageExplanationUseCase(
                contextBuilder: BuildAiContextUseCase(
                  searchRepository: const _Search(),
                ),
                artifactRepository: _Artifacts(),
                credentialRepository: const _Credentials(),
                provider: provider,
                model: 'gpt-5.6-luna',
              ),
              chapters: _chapters,
              selection: _selection,
              currentPosition: ReadingLocator(anchor: _selection.anchor),
            ),
          ),
        ),
      ),
    );

const _response = <String, Object?>{
  'explanation': 'After the rain ended, the wet street reflected light.',
  'explicitFacts': ['The rain stopped and the street shone.'],
  'interpretations': ['It may suggest renewal.'],
  'ambiguityWarning': null,
};

final class _Artifacts implements AiArtifactRepository {
  @override
  Future<AiCacheEntry?> read(String cacheId) async => null;

  @override
  Future<void> save(AiCacheEntry entry) async {}
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

final class _Search implements BookSearchRepository {
  const _Search();

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
