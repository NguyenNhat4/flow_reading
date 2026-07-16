import 'dart:async';

import 'package:flow_reading/books/book_models.dart';
import 'package:flow_reading/books/book_repository.dart';
import 'package:flow_reading/books/text_anchors.dart';
import 'package:flow_reading/reader/swipeable_reader.dart';
import 'package:flow_reading/settings/reader_settings.dart';
import 'package:flutter/material.dart';

final class ReadingPosition {
  const ReadingPosition({
    required this.bookId,
    required this.locator,
    required this.updatedAt,
  });

  final String bookId;
  final ReadingLocator locator;
  final DateTime updatedAt;
}

abstract interface class ReadingPositionRepository {
  Future<ReadingPosition?> load(String bookId);

  Future<void> save(ReadingPosition position);
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    required this.book,
    required this.bookRepository,
    required this.positionRepository,
    super.key,
  });

  final BookSummary book;
  final BookRepository bookRepository;
  final ReadingPositionRepository positionRepository;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  late final Future<List<Chapter>> _loading = _load();
  Future<void> _saveTail = Future<void>.value();
  ReadingLocator? _locator;
  bool _allowPop = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<List<Chapter>> _load() async {
    final results = await Future.wait<Object?>([
      widget.bookRepository.loadChapters(widget.book.id),
      widget.positionRepository.load(widget.book.id),
    ]);
    final chapters = results[0]! as List<Chapter>;
    final saved = results[1] as ReadingPosition?;
    _locator = saved?.locator;
    return chapters;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _savePositionWithoutBlocking();
    }
  }

  void _savePositionWithoutBlocking() {
    unawaited(_enqueuePositionSave().catchError((Object _) {}));
  }

  Future<void> _enqueuePositionSave() {
    final locator = _locator;
    if (locator == null) return Future<void>.value();
    final position = ReadingPosition(
      bookId: widget.book.id,
      locator: locator,
      updatedAt: DateTime.now().toUtc(),
    );
    final save = _saveTail.then(
      (_) => widget.positionRepository.save(position),
    );
    _saveTail = save.catchError((Object _) {});
    return save;
  }

  void _showPosition(TextAnchor anchor) {
    _locator = ReadingLocator(anchor: anchor);
    _savePositionWithoutBlocking();
  }

  Future<void> _closeReader(Object? result) async {
    if (_closing) return;
    _closing = true;
    try {
      await _enqueuePositionSave();
    } catch (_) {
      // Closing the local reader must not be blocked by a persistence failure.
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_closing) _savePositionWithoutBlocking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_closeReader(result));
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.book.title)),
        body: FutureBuilder<List<Chapter>>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('The book could not be opened.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Center(
                child: Text('This book has no readable content.'),
              );
            }
            return SwipeableReader(
              chapters: snapshot.data!,
              settings: ReaderSettings.defaults,
              initialLocator: _locator,
              onPositionChanged: _showPosition,
            );
          },
        ),
      ),
    );
  }
}
