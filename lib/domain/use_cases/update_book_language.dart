import 'package:flow_reading/domain/repositories/book_repository.dart';
import 'package:flow_reading/domain/use_cases/detect_book_language.dart';

/// Validates and persists a user-selected book language.
final class UpdateBookLanguageUseCase {
  const UpdateBookLanguageUseCase(this._repository);

  final BookRepository _repository;

  Future<void> call(String bookId, String language) =>
      _repository.updateDetectedLanguage(
        bookId,
        DetectBookLanguageUseCase.normalize(language),
      );
}
