import 'package:flow_reading/ui/features/reader/view_models/passage_explanation_view_model.dart';
import 'package:flutter/material.dart';

/// Keeps a selected passage visible while explaining it in the reader.
class PassageExplanationSheet extends StatefulWidget {
  const PassageExplanationSheet({required this.viewModel, super.key});

  final PassageExplanationViewModel viewModel;

  @override
  State<PassageExplanationSheet> createState() =>
      _PassageExplanationSheetState();
}

class _PassageExplanationSheetState extends State<PassageExplanationSheet> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final state = widget.viewModel.state;
        final viewModel = widget.viewModel;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Explain passage',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close explanation',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Card(
                    key: const ValueKey('selected-passage'),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('“${viewModel.selection.textSnapshot}”'),
                    ),
                  ),
                  if (state.isLoading) ...[
                    const SizedBox(height: 20),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    const Center(child: Text('Explaining this passage…')),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const ValueKey('cancel-passage-explanation'),
                      onPressed: viewModel.cancel,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Cancel'),
                    ),
                  ] else if (state.errorMessage case final error?) ...[
                    const SizedBox(height: 16),
                    Text(
                      error,
                      key: const ValueKey('passage-explanation-error'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const ValueKey('retry-passage-explanation'),
                      onPressed: viewModel.load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ] else if (state.explanation case final explanation?) ...[
                    if (state.fromCache)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: Icon(Icons.offline_bolt_outlined, size: 18),
                          label: Text('Saved result'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'In simpler language',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(explanation.explanation),
                    if (explanation.explicitFacts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'What the text says',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final fact in explanation.explicitFacts)
                        Text('• $fact'),
                    ],
                    if (explanation.interpretations.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Interpretation',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final interpretation in explanation.interpretations)
                        Text('• $interpretation'),
                    ],
                    if (explanation.ambiguityWarning case final warning?) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('Possible ambiguity'),
                          subtitle: Text(warning),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
