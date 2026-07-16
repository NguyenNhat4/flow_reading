sealed class AppFailure implements Exception {
  const AppFailure({required this.message});

  final String message;

  @override
  String toString() => message;
}

final class InvalidEpubFailure extends AppFailure {
  const InvalidEpubFailure({
    super.message = 'This file is not a valid EPUB book.',
  });
}

final class UnsupportedDrmFailure extends AppFailure {
  const UnsupportedDrmFailure({
    super.message = 'This book uses DRM that is not supported.',
  });
}

final class DuplicateBookFailure extends AppFailure {
  const DuplicateBookFailure({
    super.message = 'This EPUB has already been imported.',
  });
}

final class ImportCancelledFailure extends AppFailure {
  const ImportCancelledFailure({super.message = 'The import was cancelled.'});
}

final class FileSystemFailure extends AppFailure {
  const FileSystemFailure({
    super.message = 'The book file could not be read or saved.',
  });
}

final class DatabaseFailure extends AppFailure {
  const DatabaseFailure({
    super.message = 'Your reading data could not be loaded or saved.',
  });
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.message = 'A network connection could not be established.',
  });
}

final class InvalidApiKeyFailure extends AppFailure {
  const InvalidApiKeyFailure({
    super.message = 'The AI provider API key is invalid.',
  });
}

final class AiProviderFailure extends AppFailure {
  const AiProviderFailure({
    super.message = 'The AI provider could not complete the request.',
  });
}
