# Data Layer Structure (`lib/data`)

Contains implementations of Domain interfaces, local storage (SQLite/Files), and external service adapters.

## Models (`lib/data/models/`)
- `ai_artifact_record_codec.dart`: Codec for storing AI artifacts in SQLite.
- `book_record_codec.dart`: Codec for storing book records in SQLite.
- `canonical_epub_content.dart`: Data representations for normalized EPUB HTML.
- `epub_import_draft.dart`: Temporary state during EPUB parsing and import.
- `reader_state_record_codec.dart`: Codecs for reading positions and settings.

## Repositories (`lib/data/repositories/`)
Concrete implementations of domain repository ports:
- `secure_ai_credential_repository.dart`: Manages API keys securely.
- `sqlite_ai_artifact_repository.dart`: Caches AI responses locally.
- `sqlite_book_repository.dart`, `sqlite_book_search_repository.dart`: Book metadata and search.
- `sqlite_bookmark_repository.dart`, `sqlite_highlight_repository.dart`, `sqlite_note_repository.dart`: User annotations via SQLite.
- `sqlite_reader_settings_repository.dart`, `sqlite_reading_position_repository.dart`: Reading state via SQLite.
- `sqlite_table_of_contents_repository.dart`: TOC persistence.

## Services (`lib/data/services/`)
- `android_epub_picker.dart`: Native intent for selecting EPUBs.
- `app_database.dart`: SQLite database initialization and schema.
- `canonical_html_converter.dart`: Converts raw EPUB HTML to application-standard HTML.
- `epub_package_parser.dart`: Parses EPUB OPF and NCX/Nav files.
- `epub_validator.dart`: Verifies EPUB validity during import.
- `local_book_file_storage.dart`: Manages EPUB files on disk.
- `local_epub_content_parser.dart`: Reads chapters from extracted EPUBs.
- `mlkit_book_language_detector.dart`: On-device language identification.
- `open_ai_provider.dart`: Implementation for OpenAI API interactions.
- `search_segments.dart`: Text segmentation for full-text search.
- `system_utc_clock.dart`: Standard clock implementation.
