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
- `detectedLanguage`
- `importedAt`

### Chapter

`Chapter`

- `id`
- `bookId`
- `title`
- `order`
- `blocks`

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

### Content anchor

Identifies one logical source position.

`ContentAnchor`

- `bookId`
- `chapterId`
- `blockId`
- `characterOffset`

### Content range

Identifies selected source content.

`ContentRange`

- `startAnchor`
- `endAnchor`
- `textSnapshot`

### Reading position

`ReadingPosition`

- `bookId`
- `anchor`
- `updatedAt`

Never store only a page number.

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
