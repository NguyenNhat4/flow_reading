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
import 'package:flow_reading/ui/features/reader/view_models/grammar_explanation_view_model.dart';
import 'package:flow_reading/ui/features/reader/views/grammar_explanation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ties each grammar point to evidence and reading relevance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrammarExplanationSheet(
            viewModel: GrammarExplanationViewModel(
              generate: GenerateGrammarExplanationUseCase(
                contextBuilder: BuildAiContextUseCase(
                  searchRepository: const _Search(),
                ),
                artifactRepository: _Artifacts(),
                credentialRepository: const _Credentials(),
                provider: const _Provider(),
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
    await tester.pumpAndSettle();

    expect(find.text('Grammar in this passage'), findsOneWidget);
    expect(find.text('“$_text”'), findsOneWidget);
    expect(find.text('Perfect participle clause'), findsOneWidget);
    expect(find.text('Evidence: “Having finished”'), findsOneWidget);
    expect(
      find.textContaining('marks the finishing as completed'),
      findsOneWidget,
    );
    expect(find.textContaining('Why it matters:'), findsOneWidget);
    expect(find.textContaining('present perfect'), findsNothing);
  });
}

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
  const _Provider();

  @override
  String get id => 'openai';

  @override
  Future<AiCompletion> complete({
    required String apiKey,
    required AiProviderRequest request,
  }) async => AiCompletion(
    text: jsonEncode({
      'points': [
        {
          'feature': 'Perfect participle clause',
          'evidence': 'Having finished',
          'explanation':
              'The clause marks the finishing as completed before the main action.',
          'relevance':
              'It shows the order needed to understand what she did next.',
        },
      ],
      'interpretations': <String>[],
    }),
    providerId: id,
    model: request.model,
  );

  @override
  AiStreamOperation stream({
    required String apiKey,
    required AiProviderRequest request,
  }) => throw UnimplementedError();

  @override
  Future<void> validateKey(String apiKey) async {}
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
