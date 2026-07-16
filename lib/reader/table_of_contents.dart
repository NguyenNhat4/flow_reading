import 'package:flow_reading/books/book_models.dart';
import 'package:flutter/material.dart';

/// Loads a book's canonical table of contents without exposing storage details
/// to reader widgets.
abstract interface class TableOfContentsRepository {
  Future<List<TableOfContentsEntry>> load(String bookId);
}

/// Displays a nested table of contents and returns the selected reference.
Future<ChapterReference?> showReaderTableOfContents(
  BuildContext context,
  List<TableOfContentsEntry> entries,
) => showModalBottomSheet<ChapterReference>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => _TableOfContentsSheet(entries: entries),
);

class _TableOfContentsSheet extends StatelessWidget {
  const _TableOfContentsSheet({required this.entries});

  final List<TableOfContentsEntry> entries;

  @override
  Widget build(BuildContext context) {
    final flattened = <({TableOfContentsEntry entry, int depth, String key})>[];
    _flatten(entries, 0, 'root', flattened);
    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Text(
              'Table of contents',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: flattened.length,
              itemBuilder: (context, index) {
                final item = flattened[index];
                return ListTile(
                  key: ValueKey('toc-entry-${item.key}'),
                  contentPadding: EdgeInsetsDirectional.only(
                    start: 24 + item.depth * 24,
                    end: 24,
                  ),
                  title: Text(item.entry.title),
                  onTap: () => Navigator.pop(context, item.entry.reference),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void _flatten(
  List<TableOfContentsEntry> entries,
  int depth,
  String parentKey,
  List<({TableOfContentsEntry entry, int depth, String key})> result,
) {
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    final key = '$parentKey-$index';
    result.add((entry: entry, depth: depth, key: key));
    _flatten(entry.children, depth + 1, key, result);
  }
}
