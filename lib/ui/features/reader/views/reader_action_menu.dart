import 'dart:async';

import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flutter/material.dart';

/// Identifies the canonical selection that opened a reader action.
enum ReaderSelectionKind { word, passage }

/// Identifies an action available for selected reader text.
enum ReaderAction {
  define,
  askAi,
  translate,
  explain,
  summarize,
  explainGrammar,
  addNote,
  highlight,
  copy,
}

/// Immutable input passed from the reader to an action workflow.
final class ReaderActionRequest {
  const ReaderActionRequest({
    required this.action,
    required this.selectionKind,
    required this.anchor,
    required this.textSnapshot,
  });

  final ReaderAction action;
  final ReaderSelectionKind selectionKind;
  final TextAnchor anchor;
  final String textSnapshot;
}

/// Handles a reader action without coupling the reader to its implementation.
typedef ReaderActionHandler =
    FutureOr<void> Function(ReaderActionRequest request);

/// Actions shown for a selected word, in presentation order.
const wordReaderActions = <ReaderAction>[
  ReaderAction.define,
  ReaderAction.askAi,
  ReaderAction.translate,
  ReaderAction.highlight,
  ReaderAction.copy,
];

/// Actions shown for a selected passage, in presentation order.
const passageReaderActions = <ReaderAction>[
  ReaderAction.explain,
  ReaderAction.askAi,
  ReaderAction.translate,
  ReaderAction.summarize,
  ReaderAction.explainGrammar,
  ReaderAction.addNote,
  ReaderAction.highlight,
  ReaderAction.copy,
];

extension ReaderActionPresentation on ReaderAction {
  /// User-facing action name.
  String get label => switch (this) {
    ReaderAction.define => 'Define',
    ReaderAction.askAi => 'Ask AI',
    ReaderAction.translate => 'Translate',
    ReaderAction.explain => 'Explain',
    ReaderAction.summarize => 'Summarize',
    ReaderAction.explainGrammar => 'Explain Grammar',
    ReaderAction.addNote => 'Add note',
    ReaderAction.highlight => 'Highlight',
    ReaderAction.copy => 'Copy',
  };

  /// Whether this action requires network access when opened.
  bool get requiresInternet => switch (this) {
    ReaderAction.addNote ||
    ReaderAction.highlight ||
    ReaderAction.copy => false,
    _ => true,
  };
}

/// Displays the actions for the current selection without changing reader state.
class ReaderActionMenu extends StatelessWidget {
  const ReaderActionMenu({
    required this.actions,
    required this.onSelected,
    this.removeHighlight = false,
    super.key,
  });

  final List<ReaderAction> actions;
  final ValueChanged<ReaderAction> onSelected;
  final bool removeHighlight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Reader actions',
      child: SingleChildScrollView(
        key: const ValueKey('reader-action-menu'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TextButton.icon(
                  key: ValueKey('reader-action-${action.name}'),
                  onPressed: () => onSelected(action),
                  icon: action.requiresInternet
                      ? const Icon(Icons.cloud_outlined, size: 16)
                      : const SizedBox.shrink(),
                  label: Text(_label(action)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _label(ReaderAction action) {
    if (action == ReaderAction.highlight && removeHighlight) {
      return 'Remove highlight';
    }
    return action.requiresInternet ? '${action.label} · Online' : action.label;
  }
}
