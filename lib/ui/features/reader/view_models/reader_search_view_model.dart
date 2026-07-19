import 'package:flow_reading/domain/models/book_search.dart';
import 'package:flow_reading/domain/repositories/book_search_repository.dart';
import 'package:flow_reading/ui/core/ui_failure_mapper.dart';
import 'package:flutter/foundation.dart';

/// Immutable presentation state for in-book search.
final class ReaderSearchState {
  ReaderSearchState({
    this.query = '',
    List<BookSearchResult> results = const [],
    this.errorMessage,
    this.isSearching = false,
  }) : results = List.unmodifiable(results);

  final String query;
  final List<BookSearchResult> results;
  final String? errorMessage;
  final bool isSearching;
}

/// Coordinates cancellable, stale-safe searches within one book.
final class ReaderSearchViewModel extends ChangeNotifier {
  ReaderSearchViewModel({
    required this.bookId,
    required this._repository,
    this._failureMapper = const UiFailureMapper(),
  });

  final String bookId;
  final BookSearchRepository? _repository;
  final UiFailureMapper _failureMapper;

  ReaderSearchState _state = ReaderSearchState();
  int _generation = 0;
  bool _disposed = false;

  ReaderSearchState get state => _state;

  Future<void> search(String query) async {
    final generation = ++_generation;
    final normalized = query.trim();
    if (normalized.isEmpty) {
      _setState(ReaderSearchState());
      return;
    }
    final repository = _repository;
    if (repository == null) {
      _setState(
        ReaderSearchState(
          query: normalized,
          errorMessage: 'Book search is unavailable.',
        ),
      );
      return;
    }
    _setState(ReaderSearchState(query: normalized, isSearching: true));
    try {
      final results = await repository.search(
        bookId: bookId,
        query: normalized,
      );
      if (generation != _generation || _disposed) return;
      _setState(ReaderSearchState(query: normalized, results: results));
    } catch (error) {
      if (generation != _generation || _disposed) return;
      _setState(
        ReaderSearchState(
          query: normalized,
          errorMessage: _failureMapper.message(
            error,
            fallback: 'This book could not be searched.',
          ),
        ),
      );
    }
  }

  void _setState(ReaderSearchState state) {
    _state = state;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
