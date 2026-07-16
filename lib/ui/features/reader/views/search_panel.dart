import 'dart:math' as math;

import 'package:flow_reading/domain/models/book_search.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_view_model.dart';
import 'package:flutter/material.dart';

/// Searches the current book's canonical text using the local SQLite index.
class ReaderSearchPanel extends StatefulWidget {
  const ReaderSearchPanel({
    required this.viewModel,
    required this.onOpenResult,
    super.key,
  });

  final ReaderViewModel viewModel;
  final ValueChanged<BookSearchResult> onOpenResult;

  @override
  State<ReaderSearchPanel> createState() => _ReaderSearchPanelState();
}

class _ReaderSearchPanelState extends State<ReaderSearchPanel> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.viewModel.searchQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SizedBox(
            height: math.min(680, constraints.maxHeight * 0.85),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    'Search this book',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  trailing: IconButton(
                    tooltip: 'Close search',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    key: const ValueKey('reader-search-field'),
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: widget.viewModel.searchBook,
                    decoration: InputDecoration(
                      hintText: 'Search offline',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Search',
                        onPressed: () =>
                            widget.viewModel.searchBook(_controller.text),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListenableBuilder(
                    listenable: widget.viewModel,
                    builder: (context, _) => _results(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results() {
    final viewModel = widget.viewModel;
    if (viewModel.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.searchError != null) {
      return const Center(child: Text('This book could not be searched.'));
    }
    if (viewModel.searchQuery.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Enter words to search the imported book offline.'),
        ),
      );
    }
    final results = viewModel.searchResults;
    if (results.isEmpty) {
      return const Center(child: Text('No matching passages.'));
    }
    return ListView.builder(
      key: const ValueKey('reader-search-results'),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return ListTile(
          key: ValueKey('reader-search-result-${result.segment.segmentId}'),
          title: Text(
            viewModel.chapterTitleFor(result.locator.anchor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            result.excerpt,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => widget.onOpenResult(result),
        );
      },
    );
  }
}
