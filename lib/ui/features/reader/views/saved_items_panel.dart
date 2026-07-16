import 'dart:math' as math;

import 'package:flow_reading/domain/models/bookmark.dart';
import 'package:flow_reading/domain/models/reader_note.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_view_model.dart';
import 'package:flutter/material.dart';

/// Displays locally saved reader items without leaving the current book.
class ReaderSavedItemsPanel extends StatelessWidget {
  const ReaderSavedItemsPanel({
    required this.viewModel,
    required this.onOpenNote,
    required this.onOpenBookmark,
    required this.onEditNote,
    required this.onDeleteNote,
    required this.onDeleteBookmark,
    super.key,
  });

  final ReaderViewModel viewModel;
  final ValueChanged<ReaderNote> onOpenNote;
  final ValueChanged<Bookmark> onOpenBookmark;
  final ValueChanged<ReaderNote> onEditNote;
  final Future<bool> Function(ReaderNote note) onDeleteNote;
  final Future<bool> Function(Bookmark bookmark) onDeleteBookmark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SizedBox(
            height: math.min(680, constraints.maxHeight * 0.85),
            child: DefaultTabController(
              length: 2,
              child: ListenableBuilder(
                listenable: viewModel,
                builder: (context, _) => Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Saved',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      trailing: IconButton(
                        tooltip: 'Close saved items',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    const TabBar(
                      tabs: [
                        Tab(text: 'Notes'),
                        Tab(text: 'Bookmarks'),
                      ],
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: TabBarView(
                        children: [_notes(context), _bookmarks(context)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookmarks(BuildContext context) {
    final bookmarks = viewModel.bookmarks;
    if (bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            viewModel.bookmarkLoadError == null
                ? 'No bookmarks yet. Use the bookmark button while reading.'
                : 'Bookmarks could not be loaded.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('saved-bookmarks-list'),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        final anchor = bookmark.locator.anchor;
        return ListTile(
          key: ValueKey('saved-bookmark-${bookmark.id}'),
          title: Text(viewModel.chapterTitleFor(anchor)),
          subtitle: Text(
            viewModel.passagePreview(anchor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onOpenBookmark(bookmark),
          trailing: IconButton(
            tooltip: 'Remove bookmark',
            onPressed: () => _deleteBookmark(context, bookmark),
            icon: const Icon(Icons.delete_outline),
          ),
        );
      },
    );
  }

  Future<void> _deleteBookmark(BuildContext context, Bookmark bookmark) async {
    final deleted = await onDeleteBookmark(bookmark);
    if (!deleted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The bookmark could not be removed.')),
      );
    }
  }

  Widget _notes(BuildContext context) {
    final notes = viewModel.notes;
    if (notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            viewModel.noteLoadError == null
                ? 'No notes yet. Select a passage and choose Add note.'
                : 'Notes could not be loaded.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('saved-notes-list'),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return ListTile(
          key: ValueKey('saved-note-${note.id}'),
          title: Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${viewModel.chapterTitleFor(note.range)}\n'
            '${viewModel.passagePreview(note.range)}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          onTap: () => onOpenNote(note),
          trailing: PopupMenuButton<_NoteAction>(
            tooltip: 'Note actions',
            onSelected: (action) {
              switch (action) {
                case _NoteAction.edit:
                  onEditNote(note);
                case _NoteAction.delete:
                  _confirmDelete(context, note);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: _NoteAction.edit, child: Text('Edit')),
              PopupMenuItem(value: _NoteAction.delete, child: Text('Delete')),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, ReaderNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This note will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await onDeleteNote(note);
    if (!deleted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The note could not be deleted.')),
      );
    }
  }
}

enum _NoteAction { edit, delete }
