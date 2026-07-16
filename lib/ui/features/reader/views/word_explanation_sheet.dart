import 'package:flow_reading/ui/features/reader/view_models/word_explanation_view_model.dart';
import 'package:flutter/material.dart';

/// Displays a contextual word explanation without navigating away from reader.
class WordExplanationSheet extends StatefulWidget {
  const WordExplanationSheet({required this.viewModel, super.key});

  final WordExplanationViewModel viewModel;

  @override
  State<WordExplanationSheet> createState() => _WordExplanationSheetState();
}

class _WordExplanationSheetState extends State<WordExplanationSheet> {
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
                      Expanded(
                        child: Text(
                          '“${viewModel.selection.textSnapshot}”',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close explanation',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (viewModel.isLoading) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    const Center(child: Text('Reading the selected sentence…')),
                  ] else if (viewModel.errorMessage case final error?) ...[
                    const SizedBox(height: 16),
                    Text(error, key: const ValueKey('word-explanation-error')),
                  ] else if (viewModel.explanation case final explanation?) ...[
                    if (viewModel.fromCache)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: Icon(Icons.offline_bolt_outlined, size: 18),
                          label: Text('Saved result'),
                        ),
                      ),
                    _ExplanationSection(
                      title: 'Meaning here',
                      body: explanation.contextualMeaning,
                    ),
                    _ExplanationSection(
                      title: 'Part of speech',
                      body: explanation.partOfSpeech,
                    ),
                    _ExplanationSection(
                      title: 'Why this word',
                      body: explanation.reasonUsed,
                    ),
                    _ExplanationSection(
                      title: 'Simpler wording',
                      body: explanation.simplerParaphrase,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Examples',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    for (final example in explanation.examples)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• $example'),
                      ),
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

class _ExplanationSection extends StatelessWidget {
  const _ExplanationSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}
