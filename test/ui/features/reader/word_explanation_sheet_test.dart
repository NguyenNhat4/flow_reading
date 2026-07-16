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
import 'package:flow_reading/domain/use_cases/generate_word_explanation.dart';
import 'package:flow_reading/ui/features/reader/view_models/word_explanation_view_model.dart';
import 'package:flow_reading/ui/features/reader/views/word_explanation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows every contextual word explanation field', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordExplanationSheet(
            viewModel: WordExplanationViewModel(
              generate: GenerateWordExplanationUseCase(
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

    expect(find.text('“Read”'), findsOneWidget);
    expect(find.text('Mô tả từ'), findsOneWidget);
    expect(
      find.text('Động từ mô tả hành động đọc và hiểu chữ viết.'),
      findsOneWidget,
    );
    expect(find.text('Nghĩa trong ngữ cảnh'), findsOneWidget);
    expect(
      find.text('Trong câu này, “Read” có nghĩa là đọc nội dung.'),
      findsOneWidget,
    );
    expect(find.text('Ví dụ'), findsOneWidget);
    expect(find.text('• Read this chapter.'), findsOneWidget);
    expect(find.text('• I read before bed.'), findsOneWidget);
    expect(find.text('Meaning here'), findsNothing);
    expect(find.text('Part of speech'), findsNothing);
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
      'description': 'Động từ mô tả hành động đọc và hiểu chữ viết.',
      'contextualMeaning': 'Trong câu này, “Read” có nghĩa là đọc nội dung.',
      'examples': ['Read this chapter.', 'I read before bed.'],
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

final _chapters = [
  Chapter(
    id: 'chapter',
    bookId: 'book',
    title: 'Chapter',
    order: 0,
    blocks: [
      ParagraphBlock(
        id: 'block',
        chapterId: 'chapter',
        order: 0,
        spans: const [InlineTextSpan(text: 'Read locally.')],
      ),
    ],
  ),
];
