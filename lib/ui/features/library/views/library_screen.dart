import 'dart:typed_data';

import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/use_cases/import_book.dart';
import 'package:flow_reading/ui/core/ui_command_result.dart';
import 'package:flow_reading/ui/features/library/view_models/library_catalog.dart';
import 'package:flow_reading/ui/features/library/view_models/library_view_model.dart';
import 'package:flow_reading/ui/features/settings/view_models/ai_settings_view_model.dart';
import 'package:flow_reading/ui/features/settings/views/ai_settings_sheet.dart';
import 'package:flutter/material.dart';

/// Displays the local book catalog using [LibraryViewModel] state.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.viewModel,
    required this.onOpenBook,
    this.createAiSettingsViewModel,
    super.key,
  });

  final LibraryViewModel viewModel;
  final Future<void> Function(BookSummary book) onOpenBook;
  final AiSettingsViewModel Function()? createAiSettingsViewModel;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _importDialogVisible = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_handleImportState);
    widget.viewModel.load();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_handleImportState);
    widget.viewModel.dispose();
    super.dispose();
  }

  void _handleImportState() {
    if (!mounted) return;
    final importing = widget.viewModel.state.isImporting;
    if (importing && !_importDialogVisible) {
      _importDialogVisible = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ImportProgressDialog(viewModel: widget.viewModel),
      );
    } else if (!importing && _importDialogVisible) {
      _importDialogVisible = false;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();
    }
  }

  Future<void> _importBook() async {
    final result = await widget.viewModel.importSelectedBook();
    if (!mounted) return;
    if (result case UiCommandFailure<void>(:final message)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _deleteBook(BookSummary book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove book?'),
        content: Text('Remove “${book.title}” from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await widget.viewModel.remove(book);
    if (!mounted) return;
    if (result case UiCommandFailure<void>(:final message)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _changeLanguage(BookSummary book) async {
    final controller = TextEditingController(text: book.detectedLanguage ?? '');
    final language = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book language'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'BCP-47 language code',
            hintText: 'en, vi, fr, zh-Hant',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (language == null) return;
    final result = await widget.viewModel.updateLanguage(book, language);
    if (!mounted) return;
    if (result case UiCommandFailure<void>(:final message)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openBook(BookSummary book) async {
    await widget.onOpenBook(book);
    if (mounted) await widget.viewModel.load();
  }

  Future<void> _showAiSettings() async {
    final createViewModel = widget.createAiSettingsViewModel;
    if (createViewModel == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AiSettingsSheet(viewModel: createViewModel()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final state = viewModel.state;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Flow Reading'),
            actions: [
              if (widget.createAiSettingsViewModel != null)
                IconButton(
                  tooltip: 'AI settings',
                  onPressed: _showAiSettings,
                  icon: const Icon(Icons.auto_awesome_outlined),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _importBook,
            icon: const Icon(Icons.add),
            label: const Text('Import EPUB'),
          ),
          body: Builder(
            builder: (context) {
              if (state.loadErrorMessage != null) {
                return const Center(
                  child: Text('The library could not be loaded.'),
                );
              }
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.books.isEmpty) {
                return const Center(
                  child: Text('Import an EPUB to start reading.'),
                );
              }
              final visibleBooks = state.visibleBooks;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: TextField(
                          onChanged: viewModel.setQuery,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Search by title or author',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Text('Sort by'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButton<LibrarySort>(
                                value: state.sort,
                                isExpanded: true,
                                items: [
                                  for (final sort in LibrarySort.values)
                                    DropdownMenuItem(
                                      value: sort,
                                      child: Text(sort.label),
                                    ),
                                ],
                                onChanged: (sort) {
                                  if (sort != null) viewModel.setSort(sort);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (visibleBooks.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text('No books match your search.'),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                            itemCount: visibleBooks.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final book = visibleBooks[index];
                              return _BookCard(
                                book: book,
                                loadCover: widget.viewModel.coverBytes,
                                onOpen: () => _openBook(book),
                                onAction: (action) {
                                  switch (action) {
                                    case _BookAction.language:
                                      _changeLanguage(book);
                                    case _BookAction.delete:
                                      _deleteBook(book);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

enum _BookAction { language, delete }

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.loadCover,
    required this.onOpen,
    required this.onAction,
  });

  final BookSummary book;
  final Future<Uint8List?> Function(String? path) loadCover;
  final VoidCallback onOpen;
  final ValueChanged<_BookAction> onAction;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final openedAt = book.lastOpenedAt?.toLocal();
    final lastOpened = openedAt == null
        ? 'Never opened'
        : 'Last opened ${localizations.formatMediumDate(openedAt)}, '
              '${TimeOfDay.fromDateTime(openedAt).format(context)}';
    final progress = book.readingProgress.clamp(0.0, 1.0);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BookCover(loadCover: loadCover, path: book.coverPath),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.authors.isEmpty
                          ? 'Unknown author'
                          : book.authors.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(value: progress),
                        ),
                        const SizedBox(width: 10),
                        Text('${(progress * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lastOpened,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_BookAction>(
                onSelected: onAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _BookAction.language,
                    child: Text('Set language'),
                  ),
                  PopupMenuItem(
                    value: _BookAction.delete,
                    child: Text('Remove book'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.loadCover, required this.path});

  final Future<Uint8List?> Function(String? path) loadCover;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final coverPath = path;
    if (coverPath == null) return const _BookCoverFallback();
    return FutureBuilder<Uint8List?>(
      future: loadCover(coverPath),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return bytes == null
            ? const _BookCoverFallback()
            : ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  bytes,
                  width: 64,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              );
      },
    );
  }
}

class _BookCoverFallback extends StatelessWidget {
  const _BookCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.menu_book, size: 36),
    );
  }
}

class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({required this.viewModel});

  final LibraryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importing EPUB'),
      content: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              (viewModel.state.importProgress ??
                      const ImportProgress(ImportStage.validatingFile))
                  .stage
                  .label,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: viewModel.cancelImport,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
