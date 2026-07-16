# Flow Reading Folder Scope

This page explains what each folder is responsible for and what should not go
inside it.

## Quick view

| Folder | Its job | Current state |
| --- | --- | --- |
| `main.dart` | Start Flutter | Done |
| `app/` | Start features and change screens | In use |
| `books/` | Import EPUBs and describe book content | Mostly complete |
| `reader/` | Display books and manage reading activity | Early version |
| `platform/` | Work with SQLite, files, Android, and plugins | In use |
| `shared/` | Hold small pieces used by several folders | Small, in use |
| `settings/` | Manage reading preferences | Empty, future work |
| `intelligence/` | Manage AI and translation | Empty, future work |

## `lib/main.dart`

### Put here

- The command that starts Flutter.
- The root app widget.

### Do not put here

- Screens.
- Database code.
- EPUB importing.
- Reading or AI features.

This file should remain very small.

## `lib/app/`

### Put here

- App startup.
- Creating the database, storage, importer, and other helpers.
- Moving between the library and reader screens.
- Screens that join several parts of the app together.

### Do not put here

- SQLite commands.
- Direct file access.
- EPUB parsing rules.
- AI provider code.

`app/` connects the other folders. For example, it creates a SQLite book
storage helper, gives it to the library screen, and opens the reader when a
book is tapped.

## `lib/books/`

### Put here

- Book, chapter, paragraph, heading, list, quote, sentence, and image data.
- EPUB checking and importing.
- Reading EPUB metadata and chapter order.
- Cleaning EPUB HTML.
- Permanent book and text IDs.
- Exact text locations used by reading positions and future highlights.
- Import progress and cancellation.
- The list of book operations storage must support.

### Do not put here

- Reading-screen layout.
- Highlights or notes screens.
- AI explanations or translation.
- SQLite commands or Android plugin calls.

`books/` answers: “What is this EPUB, and what content is inside it?”

## `lib/reader/`

### Put here

- The reading screen.
- Chapter and future page display.
- Saving and restoring reading position.
- Future text selection, bookmarks, highlights, notes, and book search.
- Future table-of-contents navigation.

### Do not put here

- EPUB importing.
- SQLite commands.
- File-picker code.
- AI provider code.

`reader/` answers: “How does the user read and interact with an imported book?”

The current reader only shows chapters and saves a basic text-block position.
Proper screen-sized pages and reading tools are still future work.

## `lib/platform/`

### Put here

- SQLite code.
- Reading and writing files.
- Android file picker.
- Secure storage.
- Network and connectivity code.
- Phone or Flutter plugin code.
- On-device language detection.

### Do not put here

- Screen design.
- Rules describing book content.
- Reading behavior.
- AI prompts or explanation rules.

`platform/` answers: “How do we perform this operation on the real phone?”

For example, `books/` says books must be loadable. `platform/` contains the
SQLite code that actually loads them.

## `lib/shared/`

### Put here

- Small data or errors needed by several folders.

### Do not put here

- Complete features.
- Random helper functions used in only one place.
- Code that clearly belongs to books, reader, settings, or AI.

Today it mainly contains readable app errors.

## `lib/settings/`

### Put here later

- Font size and font family choices.
- Theme and color choices.
- Reader spacing and layout choices.
- Reading mode.
- AI provider choice, but not secret keys.

### Do not put here

- The actual reading screen.
- SQLite or secure-storage commands.
- AI requests.

This folder is currently empty.

## `lib/intelligence/`

### Put here later

- AI provider support.
- Word and passage explanations.
- Book chat.
- Chapter summaries.
- Translation.
- Building book text sent to AI.
- Saving or reusing generated answers.

### Do not put here

- Basic EPUB import.
- Basic local reading.
- Normal reader layout.
- Secret-key storage code.

This folder is currently empty. If AI fails or is not configured, local books
must still work.

## How the folders work together

### Importing

```text
app/ starts the import
  -> platform/ opens the Android file picker
  -> books/ checks and converts the EPUB
  -> platform/ saves files and book data
  -> app/ refreshes the library
```

### Reading

```text
app/ opens a book
  -> reader/ asks for chapters and reading position
  -> platform/ loads them from SQLite
  -> reader/ displays the content
  -> platform/ saves the new reading position
```

## Current project scope

Finished or working now:

- EPUB checking and importing.
- Local EPUB, image, and SQLite storage.
- Library list with cover, title, author, progress, and last-opened time.
- Confirmed full-book removal with staged filesystem rollback.
- Offline library search and sorting.
- Android file selection.
- Basic local chapter reading and saved position.

Partial or not started:

- Proper reading pages are not started.
- Highlights, notes, bookmarks, and reader settings are not started.
- AI and translation are not started.
- Online synchronization is intentionally postponed.

## Simple placement rule

- Book import or book content: `books/`
- Reading interaction: `reader/`
- Phone, SQLite, files, or plugins: `platform/`
- Starting features or changing screens: `app/`
- Preferences: `settings/`
- AI or translation: `intelligence/`
- Small pieces truly shared by several folders: `shared/`

Do not add another top-level folder without approval.
