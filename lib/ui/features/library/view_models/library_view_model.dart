import 'dart:async';

import 'package:flow_reading/domain/repositories/book_file_storage.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/repositories/epub_picker.dart';
import 'package:flow_reading/domain/use_cases/import_book.dart';
import 'package:flow_reading/domain/use_cases/remove_book.dart';
import 'package:flow_reading/domain/use_cases/update_book_language.dart';
import 'package:flow_reading/ui/core/ui_command_result.dart';
import 'package:flow_reading/ui/core/ui_failure_mapper.dart';
import 'package:flow_reading/ui/features/library/view_models/library_catalog.dart';
import 'package:flutter/foundation.dart';

/// Immutable presentation state for the local library.
final class LibraryState {
  LibraryState({
    List<BookSummary> books = const [],
    this.query = '',
    this.sort = LibrarySort.recentActivity,
    this.loadErrorMessage,
    this.isLoading = false,
    this.isImporting = false,
    this.importProgress,
  }) : books = List.unmodifiable(books);

  final List<BookSummary> books;
  final String query;
  final LibrarySort sort;
  final String? loadErrorMessage;
  final bool isLoading;
  final bool isImporting;
  final ImportProgress? importProgress;

  List<BookSummary> get visibleBooks =>
      filterAndSortBooks(books, query: query, sort: sort);

  LibraryState copyWith({
    List<BookSummary>? books,
    String? query,
    LibrarySort? sort,
    Object? loadErrorMessage = _unset,
    bool? isLoading,
    bool? isImporting,
    Object? importProgress = _unset,
  }) => LibraryState(
    books: books ?? this.books,
    query: query ?? this.query,
    sort: sort ?? this.sort,
    loadErrorMessage: identical(loadErrorMessage, _unset)
        ? this.loadErrorMessage
        : loadErrorMessage as String?,
    isLoading: isLoading ?? this.isLoading,
    isImporting: isImporting ?? this.isImporting,
    importProgress: identical(importProgress, _unset)
        ? this.importProgress
        : importProgress as ImportProgress?,
  );
}

const _unset = Object();

/// Owns library presentation state and user commands.
final class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({
    required this._repository,
    required this._storage,
    required this._picker,
    required this._importBook,
    required this._removeBook,
    required this._updateBookLanguage,
    this._failureMapper = const UiFailureMapper(),
  });

  final BookRepository _repository;
  final BookFileStorage _storage;
  final EpubPicker _picker;
  final ImportBookUseCase _importBook;
  final RemoveBookUseCase _removeBook;
  final UpdateBookLanguageUseCase _updateBookLanguage;
  final UiFailureMapper _failureMapper;
  final Map<String, Future<Uint8List?>> _covers = {};

  LibraryState _state = LibraryState();
  ImportOperation? _importOperation;
  StreamSubscription<ImportProgress>? _importSubscription;
  bool _disposed = false;

  LibraryState get state => _state;

  Future<void> load() async {
    _setState(_state.copyWith(isLoading: true, loadErrorMessage: null));
    try {
      final books = await _repository.listBooks();
      _setState(_state.copyWith(books: books));
    } catch (error) {
      _setState(
        _state.copyWith(
          loadErrorMessage: _failureMapper.message(
            error,
            fallback: 'The library could not be loaded.',
          ),
        ),
      );
    } finally {
      _setState(_state.copyWith(isLoading: false));
    }
  }

  void setQuery(String query) {
    if (_state.query == query) return;
    _setState(_state.copyWith(query: query));
  }

  void setSort(LibrarySort sort) {
    if (_state.sort == sort) return;
    _setState(_state.copyWith(sort: sort));
  }

  Future<UiCommandResult<void>> importSelectedBook() async {
    if (_state.isImporting) {
      return const UiCommandFailure('A book is already being imported.');
    }
    try {
      final selected = await _picker.pick();
      if (selected == null) return const UiCommandCancelled();
      final operation = _importBook.start(selected.bytes, selected.name);
      _importOperation = operation;
      await _importSubscription?.cancel();
      _importSubscription = operation.progress.listen((progress) {
        _setState(_state.copyWith(importProgress: progress));
      });
      _setState(
        _state.copyWith(
          isImporting: true,
          importProgress: const ImportProgress(ImportStage.validatingFile),
        ),
      );
      await operation.result;
      await load();
      return const UiCommandSuccess(null);
    } catch (error) {
      return UiCommandFailure(
        _failureMapper.message(
          error,
          fallback: 'The book could not be imported.',
        ),
      );
    } finally {
      await _importSubscription?.cancel();
      _importSubscription = null;
      _importOperation = null;
      _setState(_state.copyWith(isImporting: false, importProgress: null));
    }
  }

  void cancelImport() => _importOperation?.cancel();

  Future<UiCommandResult<void>> remove(BookSummary book) async {
    try {
      await _removeBook.remove(book.id);
      _covers.remove(book.coverPath);
      await load();
      return const UiCommandSuccess(null);
    } catch (error) {
      return UiCommandFailure(
        _failureMapper.message(
          error,
          fallback: 'The book could not be removed.',
        ),
      );
    }
  }

  Future<UiCommandResult<void>> updateLanguage(
    BookSummary book,
    String language,
  ) async {
    try {
      await _updateBookLanguage(book.id, language);
      await load();
      return const UiCommandSuccess(null);
    } catch (error) {
      return UiCommandFailure(
        _failureMapper.message(
          error,
          fallback: 'The book language could not be updated.',
        ),
      );
    }
  }

  Future<Uint8List?> coverBytes(String? path) {
    if (path == null) return Future<Uint8List?>.value();
    return _covers.putIfAbsent(path, () => _storage.readBytes(path));
  }

  void _setState(LibraryState state) {
    _state = state;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _importOperation?.cancel();
    unawaited(_importSubscription?.cancel());
    super.dispose();
  }
}
