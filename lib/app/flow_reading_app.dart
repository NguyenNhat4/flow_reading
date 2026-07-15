import 'dart:async';
import 'dart:typed_data';

import 'package:flow_reading/books/book_file_storage.dart';
import 'package:flow_reading/books/book_import_service.dart';
import 'package:flow_reading/books/book_language_detector.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/platform/app_database.dart';
import 'package:flow_reading/platform/epub_picker.dart';
import 'package:flow_reading/platform/local_book_file_storage.dart';
import 'package:flow_reading/platform/mlkit_book_language_detector.dart';
import 'package:flow_reading/platform/sqlite_book_repository.dart';
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
  });

  final BookRepository repository;
  final BookFileStorage storage;
  final BookImportService importService;
  final AndroidEpubPicker picker;

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

  Future<List<BookSummary>> _loadBooks() =>
      widget.services.repository.listBooks();

  void _refresh() {
    setState(() => _books = _loadBooks());
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
      await widget.services.repository.delete(book.id);
      await widget.services.storage.delete(book.id);
      if (mounted) _refresh();
    } catch (error) {
      if (!mounted) return;
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
          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return ListTile(
                leading: _BookCover(
                  storage: widget.services.storage,
                  path: book.coverPath,
                ),
                title: Text(book.title),
                subtitle: Text(
                  [
                    if (book.authors.isNotEmpty) book.authors.join(', '),
                    if (book.detectedLanguage != null) book.detectedLanguage!,
                  ].join(' • '),
                ),
                trailing: PopupMenuButton<_BookAction>(
                  onSelected: (action) {
                    switch (action) {
                      case _BookAction.language:
                        _changeLanguage(book);
                      case _BookAction.delete:
                        _deleteBook(book);
                    }
                  },
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
              );
            },
          );
        },
      ),
    );
  }
}

enum _BookAction { language, delete }

class _BookCover extends StatelessWidget {
  const _BookCover({required this.storage, required this.path});

  final BookFileStorage storage;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final coverPath = path;
    if (coverPath == null) return const Icon(Icons.menu_book, size: 40);
    return FutureBuilder<Uint8List?>(
      future: storage.readBytes(coverPath),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return bytes == null
            ? const Icon(Icons.menu_book, size: 40)
            : Image.memory(bytes, width: 40, height: 56, fit: BoxFit.cover);
      },
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
