import 'dart:async';
import 'dart:typed_data';

import 'package:flow_reading/app/library_catalog.dart';
import 'package:flow_reading/books/book_file_storage.dart';
import 'package:flow_reading/books/book_import_service.dart';
import 'package:flow_reading/books/book_language_detector.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/books/book_removal_service.dart';
import 'package:flow_reading/platform/app_database.dart';
import 'package:flow_reading/platform/epub_picker.dart';
import 'package:flow_reading/platform/local_book_file_storage.dart';
import 'package:flow_reading/platform/mlkit_book_language_detector.dart';
import 'package:flow_reading/platform/sqlite_book_repository.dart';
import 'package:flow_reading/platform/sqlite_reader_settings_repository.dart';
import 'package:flow_reading/platform/sqlite_reading_position_repository.dart';
import 'package:flow_reading/platform/sqlite_table_of_contents_repository.dart';
import 'package:flow_reading/reader/reader_screen.dart';
import 'package:flow_reading/reader/table_of_contents.dart';
import 'package:flow_reading/settings/reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class FlowReadingApp extends StatelessWidget {
  const FlowReadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flow Reading',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const _LibraryBootstrap(),
    );
  }
}

final class _LibraryServices {
  const _LibraryServices({
    required this.repository,
    required this.storage,
    required this.importService,
    required this.picker,
    required this.positionRepository,
    required this.settingsRepository,
    required this.tableOfContentsRepository,
    required this.removalService,
  });

  final BookRepository repository;
  final BookFileStorage storage;
  final BookImportService importService;
  final AndroidEpubPicker picker;
  final ReadingPositionRepository positionRepository;
  final ReaderSettingsRepository settingsRepository;
  final TableOfContentsRepository tableOfContentsRepository;
  final BookRemovalService removalService;

  static Future<_LibraryServices> create() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final database = AppDatabase();
    final repository = SqliteBookRepository(database);
    final storage = LocalBookFileStorage(supportDirectory);
    final languageDetection = BookLanguageDetectionService(
      MlKitBookLanguageDetector(),
    );
    return _LibraryServices(
      repository: repository,
      storage: storage,
      importService: BookImportService(
        repository: repository,
        storage: storage,
        languageDetection: languageDetection,
      ),
      picker: AndroidEpubPicker(),
      positionRepository: SqliteReadingPositionRepository(database),
      settingsRepository: SqliteReaderSettingsRepository(database),
      tableOfContentsRepository: SqliteTableOfContentsRepository(database),
      removalService: BookRemovalService(
        repository: repository,
        storage: storage,
      ),
    );
  }
}

class _LibraryBootstrap extends StatefulWidget {
  const _LibraryBootstrap();

  @override
  State<_LibraryBootstrap> createState() => _LibraryBootstrapState();
}

class _LibraryBootstrapState extends State<_LibraryBootstrap> {
  late final Future<_LibraryServices> _services = _LibraryServices.create();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LibraryServices>(
      future: _services,
      builder: (context, snapshot) {
        if (snapshot.hasData) return _LibraryScreen(services: snapshot.data!);
        return Scaffold(
          appBar: AppBar(title: const Text('Flow Reading')),
          body: Center(
            child: snapshot.hasError
                ? const Text('The local library could not be opened.')
                : const CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

class _LibraryScreen extends StatefulWidget {
  const _LibraryScreen({required this.services});

  final _LibraryServices services;

  @override
  State<_LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<_LibraryScreen> {
  late Future<List<BookSummary>> _books = _loadBooks();
  String _query = '';
  LibrarySort _sort = LibrarySort.recentActivity;

  Future<List<BookSummary>> _loadBooks() =>
      widget.services.repository.listBooks();

  void _refresh() {
    setState(() {
      _books = _loadBooks();
    });
  }

  Future<void> _importBook() async {
    try {
      final selected = await widget.services.picker.pick();
      if (selected == null || !mounted) return;
      final operation = widget.services.importService.start(
        selected.bytes,
        selected.name,
      );
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ImportProgressDialog(operation: operation),
        ),
      );
      await operation.result;
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _refresh();
    } catch (error) {
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
    try {
      await widget.services.removalService.remove(book.id);
      if (mounted) _refresh();
    } catch (error) {
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
    final normalized = BookLanguageDetectionService.normalize(language);
    await widget.services.repository.updateDetectedLanguage(
      book.id,
      normalized,
    );
    if (mounted) _refresh();
  }

  Future<void> _openBook(BookSummary book) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          book: book,
          bookRepository: widget.services.repository,
          positionRepository: widget.services.positionRepository,
          settingsRepository: widget.services.settingsRepository,
          tableOfContentsRepository: widget.services.tableOfContentsRepository,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flow Reading')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importBook,
        icon: const Icon(Icons.add),
        label: const Text('Import EPUB'),
      ),
      body: FutureBuilder<List<BookSummary>>(
        future: _books,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('The library could not be loaded.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final books = snapshot.data!;
          if (books.isEmpty) {
            return const Center(
              child: Text('Import an EPUB to start reading.'),
            );
          }
          final visibleBooks = filterAndSortBooks(
            books,
            query: _query,
            sort: _sort,
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
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
                            value: _sort,
                            isExpanded: true,
                            items: [
                              for (final sort in LibrarySort.values)
                                DropdownMenuItem(
                                  value: sort,
                                  child: Text(sort.label),
                                ),
                            ],
                            onChanged: (sort) {
                              if (sort != null) {
                                setState(() => _sort = sort);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (visibleBooks.isEmpty)
                    const Expanded(
                      child: Center(child: Text('No books match your search.')),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                        itemCount: visibleBooks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final book = visibleBooks[index];
                          return _BookCard(
                            book: book,
                            storage: widget.services.storage,
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
  }
}

enum _BookAction { language, delete }

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.storage,
    required this.onOpen,
    required this.onAction,
  });

  final BookSummary book;
  final BookFileStorage storage;
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
              _BookCover(storage: storage, path: book.coverPath),
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
  const _BookCover({required this.storage, required this.path});

  final BookFileStorage storage;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final coverPath = path;
    if (coverPath == null) return const _BookCoverFallback();
    return FutureBuilder<Uint8List?>(
      future: storage.readBytes(coverPath),
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
  const _ImportProgressDialog({required this.operation});

  final ImportOperation operation;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importing EPUB'),
      content: StreamBuilder<ImportProgress>(
        stream: operation.progress,
        initialData: const ImportProgress(ImportStage.validatingFile),
        builder: (context, snapshot) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(snapshot.data!.stage.label),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: operation.cancel, child: const Text('Cancel')),
      ],
    );
  }
}
