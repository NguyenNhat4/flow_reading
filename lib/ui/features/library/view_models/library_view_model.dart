import 'package:flow_reading/domain/repositories/book_file_storage.dart';
import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/repositories/epub_picker.dart';
import 'package:flow_reading/domain/use_cases/detect_book_language.dart';
import 'package:flow_reading/domain/use_cases/import_book.dart';
import 'package:flow_reading/domain/use_cases/remove_book.dart';
import 'package:flow_reading/ui/features/library/view_models/library_catalog.dart';
import 'package:flutter/foundation.dart';

/// Owns library presentation state and user commands.
final class LibraryViewModel extends ChangeNotifier {
  factory LibraryViewModel({
    required BookRepository repository,
    required BookFileStorage storage,
    required EpubPicker picker,
    required ImportBookUseCase importBook,
    required RemoveBookUseCase removeBook,
  }) => LibraryViewModel._(repository, storage, picker, importBook, removeBook);

  LibraryViewModel._(
    this._repository,
    this._storage,
    this._picker,
    this._importBook,
    this._removeBook,
  );

  final BookRepository _repository;
  final BookFileStorage _storage;
  final EpubPicker _picker;
  final ImportBookUseCase _importBook;
  final RemoveBookUseCase _removeBook;
  final Map<String, Future<Uint8List?>> _covers = {};

  List<BookSummary> _books = const [];
  String _query = '';
  LibrarySort _sort = LibrarySort.recentActivity;
  Object? _error;
  bool _isLoading = false;

  List<BookSummary> get books => _books;
  String get query => _query;
  LibrarySort get sort => _sort;
  Object? get error => _error;
  bool get isLoading => _isLoading;

  List<BookSummary> get visibleBooks =>
      filterAndSortBooks(_books, query: _query, sort: _sort);

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _books = List.unmodifiable(await _repository.listBooks());
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String query) {
    if (_query == query) return;
    _query = query;
    notifyListeners();
  }

  void setSort(LibrarySort sort) {
    if (_sort == sort) return;
    _sort = sort;
    notifyListeners();
  }

  Future<ImportOperation?> selectImport() async {
    final selected = await _picker.pick();
    if (selected == null) return null;
    return _importBook.start(selected.bytes, selected.name);
  }

  Future<void> finishImport(ImportOperation operation) async {
    await operation.result;
    await load();
  }

  Future<void> remove(BookSummary book) async {
    await _removeBook.remove(book.id);
    _covers.remove(book.coverPath);
    await load();
  }

  Future<void> updateLanguage(BookSummary book, String language) async {
    await _repository.updateDetectedLanguage(
      book.id,
      DetectBookLanguageUseCase.normalize(language),
    );
    await load();
  }

  Future<Uint8List?> coverBytes(String? path) {
    if (path == null) return Future<Uint8List?>.value();
    return _covers.putIfAbsent(path, () => _storage.readBytes(path));
  }
}
