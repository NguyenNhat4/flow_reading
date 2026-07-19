import 'package:flow_reading/app/app_composition.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/ui/features/library/views/library_screen.dart';
import 'package:flow_reading/ui/features/reader/views/reader_screen.dart';
import 'package:flutter/material.dart';

/// Root widget and asynchronous application bootstrap.
class FlowReadingApp extends StatelessWidget {
  const FlowReadingApp({required this.composition, super.key});

  final Future<AppComposition> composition;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flow Reading',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: _LibraryBootstrap(composition: composition),
    );
  }
}

class _LibraryBootstrap extends StatelessWidget {
  const _LibraryBootstrap({required this.composition});

  final Future<AppComposition> composition;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppComposition>(
      future: composition,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved != null) {
          return LibraryScreen(
            viewModel: resolved.createLibraryViewModel(),
            onOpenBook: (book) => _openBook(context, resolved, book),
            createAiSettingsViewModel: resolved.createAiSettingsViewModel,
          );
        }
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

  Future<void> _openBook(
    BuildContext context,
    AppComposition composition,
    BookSummary book,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ReaderScreen(
        viewModel: composition.createReaderViewModel(book),
        createWordExplanationViewModel:
            composition.createWordExplanationViewModel,
        createPassageExplanationViewModel:
            composition.createPassageExplanationViewModel,
        createGrammarExplanationViewModel:
            composition.createGrammarExplanationViewModel,
      ),
    ),
  );
}
