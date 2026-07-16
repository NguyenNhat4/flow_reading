# Data Model

## Principle

Canonical source content is permanent.

Visual pages are temporary.

## Content hierarchy

```text
Book
└── Chapter
    └── Block
        └── Paragraph
            └── Sentence
                └── Word or text range
```

## Core entities

### Book

`Book`

- `id`
- `metadata`
- `originalFile`
- `chapters`
- `tableOfContents`
- `assets`
- `detectedLanguage`
- `importedAt`

### Chapter

`Chapter`

- `id`
- `bookId`
- `title`
- `order`
- `blocks`
- `sourceHref`

### Content block

`ContentBlock`

- `id`
- `chapterId`
- `order`
- `type`
- `content`

Initial block types:

- `heading`
- `paragraph`
- `image`
- `list`
- `quote`

Text-bearing blocks preserve ordered inline spans. An inline span may contain:

- `text`
- `bold`
- `italic`
- `underline`
- `href`

### Sentence

`BookSentence`

- `id`
- `blockId`
- `order`
- `startOffset`
- `endOffset`
- `text`

Sentence offsets are half-open UTF-16 character offsets into the canonical
paragraph text. Sentence substrings and untouched gaps must reconstruct the
original paragraph exactly.

### Book asset

`BookAsset`

- `id`
- `bookId`
- `mediaType`
- `localPath`
- `sourceHref`

Image blocks reference assets by stable asset ID. Extracted bytes live beneath
the application-controlled book directory; the original EPUB remains unchanged.

### Text anchor

Identifies one logical source range independently of pagination.

`TextAnchor`

- `bookId`
- `chapterId`
- `blockId`
- `startOffset`
- `endOffset`

Offsets are half-open. A collapsed range, where both offsets are equal, can
represent a reading position.

### Selections and reading locator

`ReadingLocator` wraps a `TextAnchor` used to restore logical reader position.

`WordSelection` and `PassageSelection` contain:

- `anchor`
- `textSnapshot`

### Reading position

`ReadingPosition`

- `bookId`
- `anchor`
- `updatedAt`

Never store only a page number.

## Stable identity inputs

- Book ID: SHA-256 of the unchanged EPUB bytes.
- Chapter ID: book ID, spine index, and normalized source href.
- Block ID: chapter ID, canonical order/type, and deterministic DOM locator.
- Sentence ID: block ID, offsets, and exact source substring.
- Text-range ID: book/chapter/block IDs and character offsets.
- Asset ID: book ID and normalized source href.

Layout values such as page index, screen dimensions, font settings, and reading
mode are never identifier inputs.

## Local book persistence

The version-1 schema separates searchable book fields from canonical chapter
content:

- `books` stores metadata, original path, table of contents, assets, detected
  language, import time, and unique content hash.
- `chapters` stores stable chapter identity and spine order.
- `chapter_content` stores versioned canonical chapter JSON.

Other milestone tables reserve durable local state for reading positions,
annotations, bookmarks, notes, AI artifacts, chats, glossary terms, reader
preferences, and a future sync outbox. Their references must use stable anchors,
not visual pages. Creating the outbox does not enable synchronization.

### Local full-text search

Schema version 2 adds a portable local inverted index:

- `search_segments` stores one searchable text-bearing canonical block with
  `segmentId`, `bookId`, `chapterId`, `blockId`, and `plainText`.
- `search_terms` stores normalized terms and their earliest UTF-16 offset for
  indexed exact-term and prefix lookup.

The import transaction writes canonical content and search rows together.
Upgrading an existing version-1 database backfills its stored chapter JSON.
Deleting a book deletes its indexed segments and terms. Search requires every
entered term, treats the final term as a prefix, and returns a collapsed
`ReadingLocator` at the earliest match plus a surrounding-text excerpt.

### Reader settings

`ReaderSettings`

- `schemaVersion`
- `fontSize`
- `fontFamily`
- `lineHeight`
- `margins`
- `theme`
- `orientation`
- `languageMode`

Reader settings are stored as one device-global record. Missing or malformed
preferences fall back to defaults so local reading remains available. The
initial defaults use the system font at size 18, line height 1.5, horizontal
margins of 24 logical pixels, vertical margins of 16 logical pixels, the light
theme, system orientation, and original-language mode.

Language modes:

- `original`
- `vietnamese`
- `mixed`

`ReaderLayout` combines these persisted preferences with the available logical
viewport size, text scale, and pagination algorithm version. Its deterministic
cache key includes only inputs that affect page boundaries. Theme and preferred
orientation are excluded because colors do not alter measurement and the
effective orientation is already represented by viewport dimensions. Layout
keys are derived cache identifiers and must not identify durable reading data.

### Annotation

`Annotation`

- `id`
- `bookId`
- `type`
- `range`
- `note`
- `createdAt`
- `updatedAt`

Types:

- `bookmark`
- `highlight`
- `note`

Milestone 4 stores highlights in the `annotations` table with
`type = highlight`. A highlight ID is the ID of its exact canonical
`TextAnchor`, so saving the same source range is idempotent and toggling that
range can remove it. Highlight paint is temporary reader presentation state:
font changes, viewport changes, and repagination never rewrite the stored
range.

Notes use the dedicated `notes` table. Their IDs also come from the exact
canonical range, so saving another note for that range edits the existing note
while preserving its creation time. Passage previews are derived from stored
canonical chapter content instead of being duplicated in note rows. Opening a
note converts the range start into a collapsed reading locator and repaginates
to the containing page.

Bookmarks use the dedicated `bookmarks` table and accept only collapsed
`ReadingLocator` anchors. Their IDs come from that logical position, so adding
the same locator does not create duplicates. The Saved panel derives bookmark
chapter labels and surrounding text from canonical content, and opening a
bookmark resolves its anchor against newly generated page boundaries.

### Translation

`Translation`

- `id`
- `bookId`
- `sourceRange`
- `translatedText`
- `targetLanguage`
- `contextFingerprint`

### AI provider credentials

User-owned provider keys are stored only through `AiCredentialRepository`.
The Android implementation uses `flutter_secure_storage` with an isolated
namespace and Android KeyStore-backed encryption. Keys are not part of the
SQLite schema, exported book data, logs, or application error messages.

### AI provider boundary

`AiProvider` is the provider-independent domain port for key validation,
completion, and cancellable streaming. `AiProviderRequest` contains rendered
instructions, input, model selection, and an optional JSON schema, but never a
credential. Provider implementations map raw transport and service errors to
shared `AppFailure` types before returning control to application or UI code.

The initial implementation is `OpenAiProvider`, using `GET /v1/models` for
credential and default-model validation and `POST /v1/responses` for completion
and server-sent-event streaming. It sends `store: false`, uses abortable HTTP
requests for cancellation, and defaults to `gpt-5.6-luna`.

### AI context package

`AiContextPackage` contains the chapter title, current logical
`ReadingLocator`, anchored canonical passages, and recent conversation
messages. Passage roles distinguish the selection, containing sentence and
paragraph, nearby blocks, and relevant earlier passages. Context building uses
a 12,000-character default budget, keeps selected text first, merges duplicate
text while retaining all roles, and never uses a visual page number.

### AI prompt templates

`AiPromptRegistry` owns versioned prompts for word, passage, and grammar
explanations, summary, translation, chapter overview, and chat. Templates render
an `AiContextPackage` into an `AiProviderRequest`; provider adapters never own
product prompt text. Cacheable artifact prompts request strict JSON schemas,
while chat requests text. Every prompt requires fact-versus-interpretation
separation and explicit uncertainty.

### Word explanation

`WordExplanation` is a structured result containing a Vietnamese word
description, a Vietnamese explanation of its meaning in the selected context,
and at least two English examples. Prompt version 2 enforces these output
languages and replaces the earlier, broader English response shape.
`GenerateWordExplanationUseCase` builds context from the stable word range and
its containing sentence, checks the compatible artifact cache before reading a
credential, and stores only a successfully parsed response. The reader displays
the result in a modal sheet, so opening or closing it does not navigate away
from the book or change the logical reading position.

AI settings expose provider and model metadata but never read a stored key back
into the UI. A new key is validated before it replaces the securely stored key.

### Passage explanation

`PassageExplanation` separates a meaning-preserving simpler explanation from
explicit source facts, interpretations, and an optional ambiguity warning.
`GeneratePassageExplanationUseCase` checks the compatible cache before starting
a provider stream. Its session forwards completion, failure, and cancellation
as provider-independent domain events and caches only a parsed successful
completion.

The reader sheet keeps the exact selected passage visible while loading and
offers Cancel. Failure and cancellation states retain the passage and expose
Retry without moving the logical reader position.

### Grammar explanation

`GrammarExplanation` contains one or more `GrammarExplanationPoint` values.
Every point names a feature, quotes exact evidence from the selected passage,
explains the feature, and states why it matters for understanding that passage.
Interpretive notes are kept separate.

`GenerateGrammarExplanationUseCase` uses the anchored context and versioned
grammar prompt, restores compatible artifacts before network access, validates
the structured response, and caches only successful results. The reader sheet
shows the selected passage and point-by-point evidence instead of a generic
grammar lesson.

### AI conversation

`AiConversation`

- `id`
- `bookId`
- `messages`
- `createdAt`
- `updatedAt`

`AiMessage`

- `role`
- `text`
- `referencedRanges`

### Cached AI result

`AiCacheEntry`

- `id` (deterministic compatibility key)
- `bookId`
- `requestType`
- `sourceRange`
- `contentHash`
- `contextFingerprint`
- `promptId`
- `promptVersion`
- `response`
- `provider`
- `model`
- `createdAt`

Schema version 3 adds the cache compatibility columns to `ai_artifacts`.
Legacy rows without them are ignored. The cache key includes the content hash,
context fingerprint, prompt ID/version, provider, model, request type, and
stable source range, so prompt or content changes cannot silently reuse output.

## Derived data

Pagination is derived data.

`PageBoundary`

- `pageIndex`
- `startAnchor`
- `endAnchor`
- `layoutKey`

Boundary anchors are collapsed stable source positions. The end anchor is
exclusive, and it may reference a different block from the start anchor when a
page contains multiple blocks. Text block offsets use Dart UTF-16 string
offsets. List offsets use item text separated by deterministic newlines while
visual list markers consume no source offsets. Image blocks use the atomic
range `0..1`.

`PaginationResult` groups an ordered list of boundaries by chapter and layout
key. Results are temporary in-memory data and can be discarded and rebuilt.

Deleting pagination data must not delete:

- Reading position
- Annotations
- Translation
- AI references
