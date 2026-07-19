import 'package:flow_reading/domain/models/text_anchors.dart';

/// Describes why a canonical passage was included in AI context.
enum AiContextRole {
  selectedText,
  containingSentence,
  containingParagraph,
  nearbyParagraph,
  relevantEarlierPassage,
}

/// One anchored canonical passage included in an AI request.
final class AiContextPassage {
  AiContextPassage({
    required this.anchor,
    required this.text,
    required Set<AiContextRole> roles,
  }) : roles = Set.unmodifiable(roles);

  final TextAnchor anchor;
  final String text;
  final Set<AiContextRole> roles;

  AiContextPassage withRoles(Iterable<AiContextRole> additionalRoles) =>
      AiContextPassage(
        anchor: anchor,
        text: text,
        roles: {...roles, ...additionalRoles},
      );
}

/// Role of one recent message included in an AI context package.
enum AiContextMessageRole { user, assistant }

/// One recent conversation message with any referenced source ranges.
final class AiContextMessage {
  AiContextMessage({
    required this.role,
    required this.text,
    List<TextAnchor> referencedRanges = const [],
  }) : referencedRanges = List.unmodifiable(referencedRanges);

  final AiContextMessageRole role;
  final String text;
  final List<TextAnchor> referencedRanges;
}

/// Bounded book-aware input passed to an AI prompt.
final class AiContextPackage {
  AiContextPackage({
    required this.chapterTitle,
    required this.currentPosition,
    required List<AiContextPassage> passages,
    required List<AiContextMessage> recentMessages,
    required this.maxCharacters,
  }) : passages = List.unmodifiable(passages),
       recentMessages = List.unmodifiable(recentMessages) {
    if (!passages.any(
      (passage) => passage.roles.contains(AiContextRole.selectedText),
    )) {
      throw ArgumentError('Context must contain the selected text');
    }
    if (characterCount > maxCharacters) {
      throw ArgumentError('Context exceeds its character budget');
    }
  }

  final String chapterTitle;
  final ReadingLocator currentPosition;
  final List<AiContextPassage> passages;
  final List<AiContextMessage> recentMessages;
  final int maxCharacters;

  int get characterCount =>
      chapterTitle.length +
      passages.fold<int>(0, (sum, passage) => sum + passage.text.length) +
      recentMessages.fold<int>(0, (sum, message) => sum + message.text.length);

  AiContextPassage get selectedPassage => passages.firstWhere(
    (passage) => passage.roles.contains(AiContextRole.selectedText),
  );
}
