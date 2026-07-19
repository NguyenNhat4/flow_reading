import 'package:flow_reading/ui/features/reader/view_models/word_explanation_view_model.dart';
import 'package:flutter/material.dart';

/// Displays a contextual word explanation without navigating away from reader.
class WordExplanationSheet extends StatefulWidget {
  const WordExplanationSheet({required this.viewModel, super.key});

  static const heightFactor = 0.7;

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
        final state = widget.viewModel.state;
        final viewModel = widget.viewModel;
        return SafeArea(
          key: const ValueKey('word-explanation-sheet'),
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
                        tooltip: 'Đóng phần giải nghĩa',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (state.isLoading) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    const Center(child: Text('Đang đọc câu chứa từ…')),
                  ] else if (state.errorMessage case final error?) ...[
                    const SizedBox(height: 16),
                    Text(error, key: const ValueKey('word-explanation-error')),
                  ] else if (state.explanation case final explanation?) ...[
                    if (state.fromCache)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: Icon(Icons.offline_bolt_outlined, size: 18),
                          label: Text('Kết quả đã lưu'),
                        ),
                      ),
                    _ExplanationSection(
                      title: 'Mô tả từ',
                      body: explanation.description,
                    ),
                    _ExplanationSection(
                      title: 'Nghĩa trong ngữ cảnh',
                      body: explanation.contextualMeaning,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ví dụ',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    for (final example in explanation.examples)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• $example'),
                      ),
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
