# Local persistence

Schema version 1 is created by `LocalDatabase`. Foreign keys and WAL are enabled.

## Data design

- `books` references the byte-for-byte source EPUB and stores a versioned model
  snapshot for fast local loading.
- The model snapshot also records the sanitized image manifest. Image bytes are
  loaded from the untouched app-private EPUB only by normalized archive path;
  imported markup never receives filesystem access.
- `chapters` and `canonical_content` normalize stable content. The latter stores
  blocks, paragraphs, sentences, and words with hierarchy and source order.
- `content_fts` is an FTS5 projection used for local search and context retrieval.
- `reading_states` stores stable locators, not visual page numbers.
- `annotations`, `ai_cache`, `translations`, `glossary_entries`,
  `chapter_overviews`, `conversations`, `conversation_messages`, and
  `pending_sync_operations` are separate so retention and sync policy can differ.
- Indexes cover library traversal, content order, annotations, caches, glossary,
  conversations, and pending-operation scheduling.

Import first writes the untouched bytes to a staging file, then inserts all
canonical records and moves the staged file to its final app-private path inside
one database transaction. Any failure rolls back rows and removes both staged and
final files. Deletion first renames the source to a recoverable trash name, runs a
database transaction, then purges the file; failure restores it.

All listed data is local and readable without authentication or network access.
User-owned annotation/cache tables deliberately do not foreign-key to `books`,
allowing a later removal flow to retain selected associated data.

## Migration and prototype reset policy

Schema changes must increment `schemaVersion` and add an ordered `onUpgrade`
migration with a migration test. Version 1 is the prototype baseline. During
pre-release development only, if a destructive canonical-model change cannot be
migrated reliably, the developer may clear app data after recording the reset in
the release notes. A shipped build must never silently reset user data.
