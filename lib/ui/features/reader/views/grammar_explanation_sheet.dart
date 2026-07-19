import 'package:flow_reading/domain/models/grammar_explanation.dart';
import 'package:flow_reading/ui/features/reader/view_models/grammar_explanation_view_model.dart';
import 'package:flutter/material.dart';

/// Displays only grammar needed to understand the selected passage.
class GrammarExplanationSheet extends StatefulWidget {
  const GrammarExplanationSheet({required this.viewModel, super.key});

  final GrammarExplanationViewModel viewModel;

  @override
  State<GrammarExplanationSheet> createState() =>
      _GrammarExplanationSheetState();
}

class _GrammarExplanationSheetState extends State<GrammarExplanationSheet> {
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
                        'Grammar in this passage',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close grammar explanation',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Card(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('“${viewModel.selection.textSnapshot}”'),
                    ),
                  ),
                  if (state.isLoading) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text('Finding the grammar that matters…'),
                    ),
                  ] else if (state.errorMessage case final error?) ...[
                    const SizedBox(height: 16),
                    Text(
                      error,
                      key: const ValueKey('grammar-explanation-error'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const ValueKey('retry-grammar-explanation'),
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
                    for (final point in explanation.points)
                      _GrammarPointCard(point: point),
                    if (explanation.interpretations.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Interpretive notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final interpretation in explanation.interpretations)
                        Text('• $interpretation'),
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

class _GrammarPointCard extends StatelessWidget {
  const _GrammarPointCard({required this.point});

  final GrammarExplanationPoint point;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(point.feature, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Evidence: “${point.evidence}”'),
            const SizedBox(height: 8),
            Text(point.explanation),
            const SizedBox(height: 8),
            Text(
              'Why it matters: ${point.relevance}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
