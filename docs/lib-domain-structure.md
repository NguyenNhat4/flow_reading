# Domain Layer Structure (`lib/domain`)

Contains immutable business models, interface ports, and core use cases. No dependencies on UI or Data layers.

## Models (`lib/domain/models/`)
- `ai_cache_entry.dart`: AI response cache representations.
- `ai_context.dart`: Context injected into AI prompts.
- `ai_prompt.dart`: Defines AI prompt structures.
- `ai_provider_models.dart`: AI service data models.
- `app_failure.dart`: Domain-level error representations.
- `book_models.dart`: Core book entities (metadata, authors).
- `book_search.dart`: Search query and result models.
- `bookmark.dart`, `highlight.dart`, `reader_note.dart`: Reader annotation data models.
- `content_identifiers.dart`, `text_anchors.dart`: Models for EPUB content anchoring.
- `grammar_explanation.dart`, `passage_explanation.dart`, `word_explanation.dart`: AI explanation structures.
- `parsed_epub_content.dart`: In-memory parsed EPUB content models.
- `reader_session.dart`, `reader_settings.dart`, `reading_position.dart`: User reading state models.

## Repositories (`lib/domain/repositories/`)
Interfaces defining data access ports for:
- **AI**: `ai_artifact_repository.dart`, `ai_credential_repository.dart`, `ai_provider.dart`.
- **Books**: `book_file_storage.dart`, `book_repository.dart`, `epub_content_parser.dart`, `epub_picker.dart`.
- **Reading**: `book_search_repository.dart`, `bookmark_repository.dart`, `highlight_repository.dart`, `note_repository.dart`, `reader_settings_repository.dart`, `reading_position_repository.dart`, `table_of_contents_repository.dart`.
- **Utils**: `utc_clock.dart`.

## Services (`lib/domain/services/`)
- `sha256.dart`: Core hashing utility contract.

## Use Cases (`lib/domain/use_cases/`)
- **AI**: `ai_prompt_registry.dart`, `build_ai_context.dart`, `generate_grammar_explanation.dart`, `generate_passage_explanation.dart`, `generate_word_explanation.dart`.
- **Books**: `detect_book_language.dart`, `import_book.dart`, `remove_book.dart`, `update_book_language.dart`.
- **Reading**: `load_reader_session.dart`, `manage_reader_annotations.dart`, `paginate_chapter.dart`, `reader_content_index.dart`, `sentence_segmenter.dart`.
