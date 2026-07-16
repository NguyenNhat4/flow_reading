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

### Reader settings

`ReaderSettings`

- `fontSize`
- `fontFamily`
- `lineSpacing`
- `margins`
- `theme`
- `readingMode`

Reading modes:

- `original`
- `vietnamese`
- `mixed`

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

### Translation

`Translation`

- `id`
- `bookId`
- `sourceRange`
- `translatedText`
- `targetLanguage`
- `contextFingerprint`

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

- `bookId`
- `requestType`
- `sourceRange`
- `contextFingerprint`
- `response`
- `provider`
- `model`

## Derived data

Pagination is derived data.

`PageBoundary`

- `pageIndex`
- `sourceRange`
- `layoutKey`

Deleting pagination data must not delete:

- Reading position
- Annotations
- Translation
- AI references
