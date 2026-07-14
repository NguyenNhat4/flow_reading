import 'dart:io';

import 'package:flow_reading/features/import/application/epub_import_service.dart';
import 'package:flow_reading/features/import/data/epub_parser.dart';
import 'package:flow_reading/features/reader/data/epub_asset_reader.dart';
import 'package:flow_reading/shared/data/providers.dart';
import 'package:flow_reading/shared/data/sqlite_book_repository.dart';
import 'package:flow_reading/shared/domain/book.dart';
import 'package:flow_reading/shared/domain/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum LibrarySort { title, author, recent, progress }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  LibrarySort _sort = LibrarySort.title;
  ImportProgressStage? _importStage;
  String? _importError;
  Stream<List<Book>>? _libraryStream;
  BookRepository? _streamRepository;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(bookRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flow Reading'),
        actions: [
          PopupMenuButton<LibrarySort>(
            tooltip: 'Sort library',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              for (final value in LibrarySort.values)
                PopupMenuItem(
                  value: value,
                  child: Text('Sort by ${_sortLabel(value)}'),
                ),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importStage == null ? _importEpub : null,
        tooltip: 'Import an EPUB book',
        icon: const Icon(Icons.add),
        label: const Text('Import EPUB'),
      ),
      body: SafeArea(
        child: repository.when(
          loading: () => const _CenteredStatus(
            icon: Icons.hourglass_empty,
            message: 'Opening your offline library…',
          ),
          error: (error, stack) => _CenteredStatus(
            icon: Icons.error_outline,
            message: 'The local library could not be opened.',
            action: TextButton(
              onPressed: () => ref.invalidate(bookRepositoryProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (repo) {
            if (!identical(_streamRepository, repo)) {
              _streamRepository = repo;
              _libraryStream = repo.watchLibrary();
            }
            return StreamBuilder<List<Book>>(
              stream: _libraryStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _CenteredStatus(
                    icon: Icons.error_outline,
                    message:
                        'Your books could not be loaded. Existing files were not changed.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildLibrary(repo, snapshot.data!);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLibrary(BookRepository repository, List<Book> books) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = books.where((book) {
      if (query.isEmpty) return true;
      return book.metadata.title.toLowerCase().contains(query) ||
          book.metadata.authors.any(
            (author) => author.toLowerCase().contains(query),
          );
    }).toList();
    filtered.sort(
      (a, b) => switch (_sort) {
        LibrarySort.title => a.metadata.title.toLowerCase().compareTo(
          b.metadata.title.toLowerCase(),
        ),
        LibrarySort.author => a.metadata.authors.join().toLowerCase().compareTo(
          b.metadata.authors.join().toLowerCase(),
        ),
        LibrarySort.recent =>
          (b.readingState?.lastOpenedAt ?? b.importedAt).compareTo(
            a.readingState?.lastOpenedAt ?? a.importedAt,
          ),
        LibrarySort.progress => (b.readingState?.progress ?? 0).compareTo(
          a.readingState?.progress ?? 0,
        ),
      },
    );

    return Column(
      children: [
        if (_importStage != null)
          Semantics(
            liveRegion: true,
            label: _progressLabel(_importStage!),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(_progressLabel(_importStage!)),
                ),
              ],
            ),
          ),
        if (_importError != null)
          MaterialBanner(
            content: Text(_importError!),
            leading: const Icon(Icons.error_outline),
            actions: [
              TextButton(
                onPressed: () => setState(() => _importError = null),
                child: const Text('Dismiss'),
              ),
              TextButton(
                onPressed: _importEpub,
                child: const Text('Try again'),
              ),
            ],
          ),
        if (books.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search title or author',
              leading: const Icon(Icons.search),
              trailing: query.isEmpty
                  ? null
                  : [
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ],
              onChanged: (_) => setState(() {}),
            ),
          ),
        Expanded(
          child: books.isEmpty
              ? _emptyLibrary()
              : filtered.isEmpty
              ? const _CenteredStatus(
                  icon: Icons.search_off,
                  message: 'No books match this search.',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 3
                        : constraints.maxWidth >= 600
                        ? 2
                        : 1;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 176,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _BookCard(
                        book: filtered[index],
                        onOpen: () => _openBook(repository, filtered[index]),
                        onDelete: () =>
                            _confirmDelete(repository, filtered[index]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _emptyLibrary() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Semantics(
          container: true,
          label: 'Empty library',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_stories_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Your library is ready',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Import an unprotected EPUB. Your books and reading position stay on this device and work offline.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _importStage == null ? _importEpub : null,
                icon: const Icon(Icons.add),
                label: const Text('Import EPUB'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _importEpub() async {
    setState(() {
      _importError = null;
      _importStage = ImportProgressStage.reading;
    });
    try {
      final service = await ref.read(epubImportServiceProvider.future);
      final draft = await service.prepare(
        onProgress: (stage) {
          if (mounted) setState(() => _importStage = stage);
        },
      );
      if (draft == null) {
        if (mounted) setState(() => _importStage = null);
        return;
      }
      if (!mounted) return;
      final language = await _confirmLanguage(draft.book.metadata);
      if (language == null) {
        setState(() => _importStage = null);
        return;
      }
      await service.commit(
        draft.withLanguage(language),
        onProgress: (stage) {
          if (mounted) setState(() => _importStage = stage);
        },
      );
      if (mounted) {
        setState(() => _importStage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported “${draft.book.metadata.title}” for offline reading.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _importStage = null;
        _importError = _friendlyImportError(error);
      });
    }
  }

  Future<String?> _confirmLanguage(BookMetadata metadata) async {
    final controller = TextEditingController(
      text: metadata.language == 'und' ? '' : metadata.language,
    );
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm book language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metadata.language == 'und'
                  ? 'The language could not be detected confidently.'
                  : 'Detected ${metadata.language.toUpperCase()} (${((metadata.languageConfidence ?? 0) * 100).round()}% confidence).',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: metadata.language == 'und',
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'Language code',
                hintText: 'For example: en, vi, ja',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (RegExp(
                r'^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})?$',
              ).hasMatch(value)) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Confirm and import'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openBook(BookRepository repository, Book book) async {
    if (!File(book.sourcePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The original EPUB file is missing. Remove and import the book again.',
          ),
        ),
      );
      return;
    }
    await context.pushNamed('reader', pathParameters: {'bookId': book.id});
    if (mounted) setState(() => _libraryStream = repository.watchLibrary());
  }

  Future<void> _confirmDelete(BookRepository repository, Book book) async {
    var keepHighlights = false;
    var keepNotes = false;
    var keepTranslations = false;
    var keepConversations = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Remove book?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“${book.metadata.title}” and its local EPUB will be removed.',
                ),
                const SizedBox(height: 12),
                const Text('Keep selected associated data:'),
                SwitchListTile(
                  value: keepHighlights,
                  onChanged: (value) =>
                      setDialogState(() => keepHighlights = value),
                  title: const Text('Highlights'),
                ),
                SwitchListTile(
                  value: keepNotes,
                  onChanged: (value) => setDialogState(() => keepNotes = value),
                  title: const Text('Notes and bookmarks'),
                ),
                SwitchListTile(
                  value: keepTranslations,
                  onChanged: (value) =>
                      setDialogState(() => keepTranslations = value),
                  title: const Text('Translations'),
                ),
                SwitchListTile(
                  value: keepConversations,
                  onChanged: (value) =>
                      setDialogState(() => keepConversations = value),
                  title: const Text('AI conversations'),
                ),
              ],
            ),
          ),
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
      ),
    );
    if (confirmed != true) return;
    await repository.delete(
      book.id,
      deleteAssociatedData: true,
      retainedData: {
        if (keepHighlights) AssociatedDataKind.highlights,
        if (keepNotes) AssociatedDataKind.notes,
        if (keepTranslations) AssociatedDataKind.translations,
        if (keepConversations) AssociatedDataKind.conversations,
      },
    );
  }

  String _friendlyImportError(Object error) {
    if (error is EpubImportException) return error.message;
    if (error is DuplicateBookException || error is StateError) {
      return 'This EPUB is already in your library.';
    }
    if (error is FileSystemException) {
      return 'The selected EPUB could not be read or saved. Check available storage and try again.';
    }
    return 'The EPUB could not be imported. Existing books were not changed.';
  }

  static String _sortLabel(LibrarySort value) => switch (value) {
    LibrarySort.title => 'title',
    LibrarySort.author => 'author',
    LibrarySort.recent => 'recent activity',
    LibrarySort.progress => 'progress',
  };

  static String _progressLabel(ImportProgressStage stage) => switch (stage) {
    ImportProgressStage.reading => 'Choose an EPUB to import',
    ImportProgressStage.validating => 'Validating and extracting the EPUB…',
    ImportProgressStage.awaitingLanguage => 'Confirm the detected language',
    ImportProgressStage.saving => 'Saving the book for offline reading…',
    ImportProgressStage.complete => 'Import complete',
  };
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.onOpen,
    required this.onDelete,
  });

  final Book book;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = book.readingState?.progress ?? 0;
    final missing = !File(book.sourcePath).existsSync();
    return Semantics(
      button: true,
      label:
          '${book.metadata.title}, ${book.metadata.authors.join(', ')}, ${(progress * 100).round()} percent read${missing ? ', source file missing' : ''}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(width: 92, height: 140, child: _Cover(book: book)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.metadata.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.metadata.authors.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (missing)
                        const Text(
                          'Source file missing',
                          style: TextStyle(color: Colors.red),
                        ),
                      Text('${(progress * 100).round()}% read'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Text(
                        'Last opened ${_date(book.readingState?.lastOpenedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${book.metadata.title}',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _date(DateTime? value) {
    if (value == null) return 'never';
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final coverId = book.metadata.coverImageId;
    final image = coverId == null
        ? null
        : book.images.where((value) => value.id == coverId).firstOrNull;
    if (image == null) return _placeholder(context);
    return FutureBuilder(
      future: EpubAssetReader.load(book.sourcePath, image.relativePath),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return _placeholder(context);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _placeholder(context),
          semanticLabel: 'Cover of ${book.metadata.title}',
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
    ),
    child: Center(
      child: Text(
        book.metadata.title.characters.firstOrNull?.toUpperCase() ?? '?',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
    ),
  );
}

class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({
    required this.icon,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
