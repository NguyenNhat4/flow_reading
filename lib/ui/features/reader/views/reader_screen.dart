import 'dart:async';

import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/ui/core/reader_theme.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_view_model.dart';
import 'package:flow_reading/ui/features/reader/views/reader_layout_controls.dart';
import 'package:flow_reading/ui/features/reader/views/reader_action_menu.dart';
import 'package:flow_reading/ui/features/reader/views/saved_items_panel.dart';
import 'package:flow_reading/ui/features/reader/views/search_panel.dart';
import 'package:flow_reading/ui/features/reader/views/swipeable_reader.dart';
import 'package:flow_reading/ui/features/reader/views/table_of_contents.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays a reader session whose state is owned by [ReaderViewModel].
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({required this.viewModel, super.key});

  final ReaderViewModel viewModel;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  bool _allowPop = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.viewModel.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.viewModel.saveForLifecycleChange();
    }
  }

  Future<void> _closeReader(Object? result) async {
    if (_closing) return;
    _closing = true;
    try {
      await widget.viewModel.savePosition();
    } catch (_) {
      // A local persistence failure must not trap the user in the reader.
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop(result);
  }

  Future<void> _changeLayout() async {
    final updated = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReaderLayoutControls(settings: widget.viewModel.settings),
    );
    if (updated == null || !mounted) return;
    final saved = await widget.viewModel.updateSettings(updated);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reader settings could not be saved.')),
      );
    }
  }

  Future<void> _showTableOfContents() async {
    final reference = await showReaderTableOfContents(
      context,
      widget.viewModel.tableOfContents,
    );
    if (reference == null || !mounted) return;
    if (!widget.viewModel.navigateTo(reference)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This section could not be opened.')),
      );
    }
  }

  Future<void> _handleAction(ReaderActionRequest request) async {
    if (request.action == ReaderAction.addNote) {
      await _editNote(request.anchor);
      return;
    }
    if (request.action == ReaderAction.highlight) {
      final saved = await widget.viewModel.toggleHighlight(request.anchor);
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The highlight could not be saved.')),
        );
      }
      return;
    }
    if (request.action == ReaderAction.copy || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${request.action.label} requires internet access.'),
      ),
    );
  }

  Future<void> _editNote(TextAnchor range) async {
    final existing = widget.viewModel.noteFor(range);
    final controller = TextEditingController(text: existing?.body);
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add note' : 'Edit note'),
        content: TextField(
          key: const ValueKey('reader-note-field'),
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Write a note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.trim().isEmpty || !mounted) return;
    final saved = await widget.viewModel.saveNote(range, body);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The note could not be saved.')),
      );
    }
  }

  Future<void> _showSavedItems() async {
    final anchor = await showModalBottomSheet<TextAnchor>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => ReaderSavedItemsPanel(
        viewModel: widget.viewModel,
        onOpenNote: (note) => Navigator.of(sheetContext).pop(note.range),
        onOpenBookmark: (bookmark) =>
            Navigator.of(sheetContext).pop(bookmark.locator.anchor),
        onEditNote: (note) => _editNote(note.range),
        onDeleteNote: (note) => widget.viewModel.deleteNote(note.id),
        onDeleteBookmark: (bookmark) =>
            widget.viewModel.deleteBookmark(bookmark.id),
      ),
    );
    if (anchor == null || !mounted) return;
    if (!widget.viewModel.navigateToAnchor(anchor)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This note passage could not be opened.')),
      );
    }
  }

  Future<void> _toggleBookmark() async {
    final saved = await widget.viewModel.toggleBookmark();
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The bookmark could not be updated.')),
      );
    }
  }

  Future<void> _showSearch() async {
    final anchor = await showModalBottomSheet<TextAnchor>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => ReaderSearchPanel(
        viewModel: widget.viewModel,
        onOpenResult: (result) =>
            Navigator.of(sheetContext).pop(result.locator.anchor),
      ),
    );
    if (anchor == null || !mounted) return;
    if (!widget.viewModel.navigateToAnchor(anchor)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This search result could not be opened.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_closing) widget.viewModel.saveForLifecycleChange();
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final theme = readerThemeData(viewModel.settings.theme);
        final systemUiStyle = readerSystemUiStyle(theme.colorScheme);
        return Theme(
          key: const ValueKey('reader-theme'),
          data: theme,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            key: const ValueKey('reader-system-ui-style'),
            value: systemUiStyle,
            child: PopScope<Object?>(
              canPop: _allowPop,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) unawaited(_closeReader(result));
              },
              child: Scaffold(
                appBar: AppBar(
                  title: Text(viewModel.book.title),
                  systemOverlayStyle: systemUiStyle,
                  actions: [
                    IconButton(
                      tooltip: 'Table of contents',
                      onPressed: viewModel.tableOfContents.isEmpty
                          ? null
                          : _showTableOfContents,
                      icon: const Icon(Icons.list_alt),
                    ),
                    IconButton(
                      tooltip: 'Saved items',
                      onPressed: viewModel.isLoaded ? _showSavedItems : null,
                      icon: const Icon(Icons.collections_bookmark_outlined),
                    ),
                    IconButton(
                      tooltip: viewModel.isCurrentPositionBookmarked
                          ? 'Remove bookmark'
                          : 'Add bookmark',
                      onPressed: viewModel.locator == null
                          ? null
                          : _toggleBookmark,
                      icon: Icon(
                        viewModel.isCurrentPositionBookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                      ),
                    ),
                    PopupMenuButton<_ReaderMenuAction>(
                      tooltip: 'More reader actions',
                      enabled: viewModel.isLoaded,
                      onSelected: (action) {
                        switch (action) {
                          case _ReaderMenuAction.search:
                            _showSearch();
                          case _ReaderMenuAction.layout:
                            _changeLayout();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _ReaderMenuAction.search,
                          child: ListTile(
                            leading: Icon(Icons.search),
                            title: Text('Search this book'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ReaderMenuAction.layout,
                          child: ListTile(
                            leading: Icon(Icons.text_fields),
                            title: Text('Reader layout'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                body: _ReaderBody(
                  viewModel: viewModel,
                  onActionSelected: _handleAction,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _ReaderMenuAction { search, layout }

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({required this.viewModel, required this.onActionSelected});

  final ReaderViewModel viewModel;
  final ReaderActionHandler onActionSelected;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.loadError != null) {
      return const Center(child: Text('The book could not be opened.'));
    }
    if (viewModel.chapters.isEmpty) {
      return const Center(child: Text('This book has no readable content.'));
    }
    return SwipeableReader(
      key: ValueKey('reader-generation-${viewModel.readerGeneration}'),
      chapters: viewModel.chapters,
      settings: viewModel.settings,
      initialLocator: viewModel.locator,
      highlights: viewModel.highlights,
      onPositionChanged: viewModel.showPosition,
      onActionSelected: onActionSelected,
    );
  }
}
