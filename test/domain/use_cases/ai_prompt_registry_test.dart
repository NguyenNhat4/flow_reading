import 'dart:convert';

import 'package:flow_reading/domain/models/ai_context.dart';
import 'package:flow_reading/domain/models/ai_prompt.dart';
import 'package:flow_reading/domain/models/ai_provider_models.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/use_cases/ai_prompt_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiPromptRegistry', () {
    test('registers one unique versioned template for every request type', () {
      final templates = AiPromptRegistry.all;

      expect(templates, hasLength(AiRequestType.values.length));
      expect(templates.map((template) => template.requestType), {
        ...AiRequestType.values,
      });
      expect(templates.map((template) => template.id).toSet(), hasLength(7));
      expect(templates.map((template) => template.version), everyElement(1));
    });

    test('every prompt grounds facts, interpretations, and uncertainty', () {
      for (final template in AiPromptRegistry.all) {
        final instructions = template.instructions.toLowerCase();
        expect(instructions, contains('canonical book context'));
        expect(instructions, contains('facts'));
        expect(instructions, contains('interpretation'));
        expect(instructions, contains('uncertainty'));
      }
    });

    test('artifact prompts use strict schemas and chat uses text', () {
      for (final template in AiPromptRegistry.all) {
        if (template.requestType == AiRequestType.chat) {
          expect(template.responseFormat, isA<AiTextResponseFormat>());
          continue;
        }
        final format = template.responseFormat as AiJsonResponseFormat;
        expect(format.name, template.id);
        expect(format.schema['type'], 'object');
        expect(format.schema['required'], isA<List>());
        expect(format.schema['additionalProperties'], isFalse);
      }
      final word =
          AiPromptRegistry.templateFor(
                AiRequestType.wordExplanation,
              ).responseFormat
              as AiJsonResponseFormat;
      final properties = (word.schema['properties'] as Map)
          .cast<String, Object?>();
      final examples = (properties['examples'] as Map).cast<String, Object?>();
      expect(examples['minItems'], 2);
    });

    test('renders stable anchors and prompt metadata without page fields', () {
      final template = AiPromptRegistry.templateFor(
        AiRequestType.wordExplanation,
      );
      final request = template.buildRequest(
        model: 'reader-model',
        context: _context,
      );
      final input = (jsonDecode(request.input) as Map).cast<String, Object?>();
      final context = (input['context'] as Map).cast<String, Object?>();
      final passages = context['passages'] as List<Object?>;
      final selected = (passages.first as Map).cast<String, Object?>();
      final anchor = (selected['anchor'] as Map).cast<String, Object?>();

      expect(request.model, 'reader-model');
      expect(input['promptId'], template.id);
      expect(input['promptVersion'], 1);
      expect(anchor['bookId'], 'book');
      expect(anchor['chapterId'], 'chapter');
      expect(anchor['blockId'], 'block');
      expect(request.input.toLowerCase(), isNot(contains('pageindex')));
      expect(request.input.toLowerCase(), isNot(contains('pagenumber')));
    });

    test('requires translation language and chat question', () {
      final translation = AiPromptRegistry.templateFor(
        AiRequestType.translation,
      );
      final chat = AiPromptRegistry.templateFor(AiRequestType.chat);

      expect(
        () => translation.buildRequest(model: 'model', context: _context),
        throwsArgumentError,
      );
      expect(
        () => chat.buildRequest(model: 'model', context: _context),
        throwsArgumentError,
      );
      final translationRequest = translation.buildRequest(
        model: 'model',
        context: _context,
        targetLanguage: 'vi',
      );
      final chatRequest = chat.buildRequest(
        model: 'model',
        context: _context,
        question: 'Why is this important?',
      );
      expect(translationRequest.input, contains('"targetLanguage":"vi"'));
      expect(chatRequest.input, contains('Why is this important?'));
    });
  });
}

final _selection = TextAnchor(
  bookId: 'book',
  chapterId: 'chapter',
  blockId: 'block',
  startOffset: 0,
  endOffset: 4,
);

final _context = AiContextPackage(
  chapterTitle: 'Chapter title',
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
      anchor: _selection,
      text: 'Word',
      roles: const {AiContextRole.selectedText},
    ),
  ],
  recentMessages: [
    AiContextMessage(
      role: AiContextMessageRole.user,
      text: 'What does this mean?',
      referencedRanges: [_selection],
    ),
  ],
  maxCharacters: 1000,
);
