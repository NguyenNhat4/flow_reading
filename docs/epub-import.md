# EPUB Import Reference

## Purpose

This document describes the durable Milestone 1 EPUB import design. Acceptance
criteria remain authoritative; this reference explains how the implemented
stages interact and where future changes belong.

## Import orchestration

`BookImportService` coordinates one import without exposing plugins, files, or
SQLite to widgets.

```text
AndroidEpubPicker
  → EpubValidator
  → BookFileStorage.stageOriginal
  → EpubPackageParser
  → CanonicalHtmlConverter
  → SentenceSegmenter
  → BookLanguageDetectionService
  → BookFileStorage.stageAsset/commit
  → BookRepository.save
```

CPU-heavy ZIP, XML, and HTML processing runs through an isolate. The operation
exposes a progress stream, a result future, and cancellation. Current stages are
validation, copying, metadata, chapters, language, images, saving, and complete.

The library UI depends on the picker and books-owned contracts. Platform wiring
is created in `lib/app/flow_reading_app.dart`; widgets do not open databases or
read files directly.

On Android, `AndroidEpubPicker` opens the system document picker for a single
file and reads the selected document into memory. The native chooser is left
unfiltered because Android document providers do not consistently map EPUB
extensions to MIME types; the platform adapter instead applies a
case-insensitive `.epub` filename check before starting `BookImportService`.
Cancelling the system picker returns `null`, so no import operation starts and
the library remains unchanged. EPUB structure is still verified by
`EpubValidator` as the first import stage.

After a successful save, the library reloads immediately and presents the
persisted cover, title, authors, reading progress, and last-opened time. Opening
a book loads canonical chapters locally through `BookRepository`; reading state
is stored as a stable `ReadingLocator` in `reading_states`, never as a visual
page number. Books without reading state display zero progress and have not yet
been opened. The loaded summaries are searched in memory by title or author and
can be sorted by title, author, recent activity, reading progress, or import
date; these catalog operations require no network access.

## Validation

`EpubValidator` accepts bytes and returns a decoded archive, package-document
path, and ordered spine resource paths.

It checks:

- readable ZIP structure;
- first, uncompressed `mimetype` entry with `application/epub+zip`;
- `META-INF/container.xml` and its declared package document;
- package manifest and non-empty spine;
- every spine reference and chapter resource;
- unsafe archive resource paths;
- `rights.xml` and declared encrypted data.

Structural errors become `InvalidEpubFailure`. Rights management or encryption
becomes `UnsupportedDrmFailure`. Validation performs no persistence writes.

Current limitation: all declared encryption is rejected, including EPUBs that
use permitted font obfuscation.

## Storage lifecycle

`BookFileStorage` is a books-owned contract. `LocalBookFileStorage` implements it
under the application-support directory:

```text
books/
└── <bookId>/
    ├── original.epub
    └── assets/
```

The unchanged source bytes are first written to a unique temporary sibling
directory. A successful import promotes that directory atomically. Duplicate
content is detected by the content-addressed book ID and never overwrites an
existing directory.

Cleanup rules:

- cancellation or parsing failure deletes the temporary directory;
- database failure after promotion deletes the newly promoted directory;
- existing imported books are never changed by a failed import;
- deletion removes database rows and the application-controlled book directory,
  never the user's original source file.

Book removal first renames the application-controlled book directory to a
temporary removal path. The database then deletes the selected book in one
transaction; foreign-key cascades remove its canonical content and all related
local state without touching other books. A database failure restores the
staged directory, while success permanently removes it. The library always asks
for confirmation before starting this flow.

## Package parsing

`EpubPackageParser` reads the OPF package and produces `EpubImportDraft`.

The draft contains:

- normalized Dublin Core metadata;
- spine-ordered chapter descriptors with stable IDs;
- recursive table-of-contents entries;
- EPUB 3 navigation or EPUB 2 NCX fallback;
- EPUB 3 or EPUB 2 cover discovery and cover bytes.

Missing optional metadata is allowed. Missing title falls back to the selected
filename, then `Untitled`. Chapter titles prefer navigation labels and otherwise
fall back to their resource filename. TOC references always contain a stable
chapter ID; a fragment may later resolve to a stable block ID.

## Canonical conversion

`CanonicalHtmlConverter` uses a tolerant HTML5 parser. It walks chapter DOM nodes
in source order and creates headings, paragraphs, quotes, lists, and images.

Supported inline semantics are bold, italic, underline, line breaks, and links.
Scripts, styles, forms, embedded objects, iframes, and canvases are discarded.
Unknown safe containers contribute their descendant content in document order.

Block IDs use deterministic DOM locators and canonical order. Element fragments
are mapped to block IDs so table-of-contents navigation can become more precise.
Images resolve relative to their chapter, receive stable asset IDs, and must
exist in the archive. Extracted image bytes are staged separately; image blocks
store only the asset ID.

## Sentence segmentation

`SentenceSegmenter` partitions canonical paragraph text using half-open UTF-16
offsets. It supports English and Vietnamese sentence punctuation and protects
common abbreviations, initials, decimal numbers, and ellipses from obvious false
splits.

Every `BookSentence` stores its exact source substring, order, offsets, block ID,
and deterministic sentence ID. Joining its sentence substrings reconstructs the
paragraph text exactly, including whitespace between sentences.

## Language detection

`BookLanguageDetectionService` samples up to 20,000 characters from canonical
headings, paragraphs, quotes, and lists. The platform adapter uses bundled,
on-device ML Kit identification with a 0.5 confidence threshold.

Results are normalized to BCP-47. `und`, short text, plugin failure, or detection
failure falls back to normalized EPUB language metadata, then unknown. Detection
never blocks import. The effective value is persisted in `Book.detectedLanguage`
and can be manually corrected from the library; declared EPUB metadata remains
unchanged.

## Repository and database

`BookRepository` belongs to `books`; `SqliteBookRepository` is the platform
implementation. It supports saving, summaries, metadata, ordered chapter loads,
duplicate checks, language updates, and deletion.

An imported book and all chapter content are saved in one SQLite transaction.
The schema is versioned by `AppDatabase`; foreign keys and cascading book-owned
rows are enabled. Implementation exceptions are translated to `DatabaseFailure`.

The schema deliberately has no permanent `pages` table. Pagination is derived
later from canonical content and reader layout.

## Focused validation

Run the narrowest relevant test first:

```bash
flutter test test/books/epub_validator_test.dart
flutter test test/books/epub_package_parser_test.dart
flutter test test/books/canonical_html_converter_test.dart
flutter test test/books/sentence_segmenter_test.dart
flutter test test/platform/app_database_test.dart
flutter test test/platform/sqlite_book_repository_test.dart
flutter test test/books/book_import_service_test.dart
```

Run the complete suite when canonical models, persistence schema, or public
contracts change. Android integration should also be built and launched on the
connected phone after plugin or application-wiring changes.
