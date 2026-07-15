# Product Plan

## 1. Product objective

Build an Android reading application for imported EPUB books that presents content as a natural swipeable book and helps readers understand difficult language without leaving the reading experience.

The product combines:

- Paginated left/right reading.
- Context-aware word and passage explanations.
- Reader-aware AI chat.
- Chapter overviews.
- Original, Vietnamese, and mixed-language reading modes.
- Offline core reading.
- Locally cached generated content.
- Bring-your-own-AI-key support.
- Optional account synchronization.
- No mandatory account for local reading.

---

## 2. Confirmed product decisions

| Area | Decision |
|---|---|
| Initial platform | Android |
| Framework | Flutter |
| Initial content type | User-uploaded EPUB |
| Reading style | Paginated left/right swiping |
| Core reading | Offline |
| Account for local reading | Not required |
| Initial AI | Online using the user’s API key |
| Developer-owned AI key | Not included |
| Future AI | Offline where technically practical |
| Initial translation target | Vietnamese |
| Reading modes | Original, VN, MIX |
| Source language | Detected from imported book and correctable by user |
| Chapter overview | Explains the chapter ahead and its big picture |
| Synchronization | Optional and account-based |
| PDF | Later |
| OCR | Later |
| Marketplace | Not included |
| Fixed-layout reproduction | Not required |

---

## 3. Primary user flow

```text
User imports EPUB
    ↓
Application parses and stores book locally
    ↓
User opens book
    ↓
Application restores logical reading position
    ↓
User reads through swipeable pages
    ↓
User taps a word or selects a passage
    ↓
User defines, explains, translates, highlights, or asks AI
    ↓
Generated result is shown without leaving the reader
    ↓
Result may be cached for offline access
```

---

## 4. EPUB import requirements

The application must:

- Import valid, unprotected EPUB files.
- Extract available metadata.
- Extract the cover.
- Extract the table of contents.
- Preserve chapter and content order.
- Extract paragraphs, sentences, images, and relevant formatting.
- Detect the book’s primary language.
- Allow correction of detected language.
- Retain the original EPUB without modifying it.
- Assign stable identities to addressable source content.
- Reject corrupted or unsupported files without affecting existing books.
- Explain unsupported DRM clearly.

---

## 5. Library requirements

The local library must:

- Work without an account.
- Display book cover, title, author, progress, and last-opened information.
- Open books at their most recently saved logical reading position.
- Support local book removal with confirmation.
- Let the user decide whether related notes, highlights, translations, and AI conversations are also removed.
- Eventually support library search and sorting.

Library search and sorting belong to the complete MVP and do not need to block the first reader prototype.

---

## 6. Reader requirements

The reader must:

- Present EPUB content as paginated pages.
- Move forward by swiping left.
- Move backward by swiping right.
- Support portrait and landscape orientation.
- Provide light, dark, and paper-like themes.
- Allow configuration of font and layout settings.
- Repaginate after layout changes.
- Preserve logical reading position after repagination.
- Save position locally when backgrounded or closed.
- Provide access to table of contents.
- Eventually provide bookmarks, highlights, notes, and in-book search.

Visual page numbers must not be used as permanent content identity.

---

## 7. Word interaction requirements

Tapping a word should:

1. Select the word.
2. Keep the word visibly connected to its sentence.
3. Open a compact action menu.

Actions:

- Define.
- Ask AI.
- Translate.
- Highlight.
- Copy.

A contextual word explanation should provide:

- Meaning in the current sentence.
- Part of speech.
- Why the word is used in the passage.
- A simpler paraphrase.
- At least two natural usage examples.

When multiple meanings are plausible, uncertainty must be explained instead of hidden.

---

## 8. Sentence and passage requirements

Long-pressing text should permit sentence or passage selection.

Actions:

- Explain.
- Ask AI.
- Translate.
- Summarize.
- Explain grammar.
- Highlight.
- Copy.

Explain behavior:

- Use simpler language.
- Preserve intended meaning.
- Avoid unrelated background information.

Grammar behavior:

- Explain only grammar needed to understand the selected passage.

While AI is generating:

- Keep the selected text visible.
- Allow reading to continue when practical.
- Allow cancellation.
- Preserve reading position.

---

## 9. AI requirements

AI is an optional enhancement, not a reading dependency.

The application must:

- Require user configuration of a supported provider.
- Validate the API key before enabling actions.
- Store the key in protected credential storage.
- Never ship a developer-owned production key.
- Use a provider-independent application interface.
- Build context from canonical book content.
- Cache successful responses locally.
- Keep local reading operational when AI fails.

Possible context:

- Selected text.
- Containing sentence.
- Containing paragraph.
- Nearby paragraphs.
- Current chapter.
- Logical reading position.
- Relevant earlier book passages.
- Recent messages in the active conversation.

When AI introduces an interpretation that the author did not explicitly state, the response should identify it as an interpretation.

---

## 10. Reader chatbot requirements

The chatbot should:

- Open without navigating away from the active book.
- Know the active book.
- Know the current chapter.
- Know the current logical reading position.
- Know the visible or selected passage.
- Update active context when the reader moves.
- Allow natural-language questions without manual copying.
- Retain relevant messages within the active conversation.
- Link answers back to referenced passages when possible.
- Associate saved conversations with their book.

The chatbot must not automatically send the entire book for every question.

---

## 11. Chapter overview requirements

At the beginning of a chapter, the application should offer a Chapter Overview action.

An overview should analyze the complete chapter and include:

- The big picture.
- Main ideas or events.
- Important concepts and terminology.
- Chapter structure.
- What the reader should pay attention to.

The UI must indicate that the overview may discuss content ahead.

Generated overviews should be cached.

A cached overview is loaded unless the user explicitly regenerates it.

If chapter boundaries are unreliable, the application should ask the user to select the section to analyze.

---

## 12. Language and translation requirements

The initial translation target is Vietnamese.

### Original mode

Display source text without AI translation.

### VN mode

Display Vietnamese translation in place of source text.

### MIX mode

Display each original sentence followed by its Vietnamese translation.

Translation should consider:

- Surrounding paragraph.
- Current chapter.
- Book-specific terminology.
- Established writing style.
- Authorial tone, voice, and intent.

The application should maintain a terminology glossary per book.

Generated translation should be cached locally.

Switching reading mode must preserve logical reading position.

Offline behavior:

- Show cached translation when available.
- Otherwise show original content.
- Explain that uncached translation is unavailable offline.

---

## 13. Account and synchronization requirements

An account must not be required for:

- Importing a local book.
- Opening a local book.
- Reading offline.
- Saving local reading progress.
- Using local annotations.

An account may be required when synchronization is enabled.

Synchronizable data may include:

- Reading position.
- Bookmarks.
- Highlights.
- Notes.
- Reader preferences.
- Original EPUB files when explicitly enabled.

Offline changes must remain local and synchronize when connectivity returns.

Conflict rules:

- Reading-position conflict: retain the most recently updated position.
- Preserve all annotations.
- Conflicting note text: preserve both versions until resolution.

Disabling synchronization must not delete local books or local reading data.

Account deletion must remove synchronized personal data and cloud-stored book files after confirmation.

---

## 14. Offline behavior

Offline reading is a core feature.

While offline, users must be able to:

- Open imported books.
- Navigate the table of contents.
- Read paginated content.
- Change reader settings.
- Restore and save reading position.
- Access local annotations.
- Access previously cached translations.
- Access previously cached AI output.

When an uncached online feature is requested:

1. Explain that connectivity is required.
2. Preserve the reader state.
3. Keep original content visible.
4. Avoid treating the request as successfully completed.

---

## 15. Implementation roadmap

### Phase 1 — Reader prototype

Goal: prove that an EPUB can become a pleasant swipeable book.

Deliver:

- Import one unprotected EPUB.
- Parse metadata, chapters, and table of contents.
- Build canonical source content.
- Assign stable content identity.
- Persist locally.
- Paginate content.
- Swipe left and right.
- Change font size and theme.
- Repaginate while preserving position.
- Tap a word.
- Select a sentence or passage.

### Phase 2 — AI prototype

Goal: prove that book-aware explanations are more useful than a normal dictionary.

Deliver:

- User-provided AI key.
- Secure key storage.
- Provider-independent interface.
- Context builder.
- Contextual word explanation.
- Passage explanation.
- Reader chatbot.
- Locally cached AI responses.
- Clear offline and error states.

### Phase 3 — Translation and chapter intelligence

Deliver:

- Source-language detection.
- User correction of detected language.
- Chapter overview.
- Original mode.
- VN mode.
- MIX mode.
- Chapter-aware translation.
- Per-book terminology glossary.
- Translation cache.
- Position preservation when switching modes.

### Phase 4 — Complete MVP

Deliver:

- Library search and sorting.
- Bookmarks.
- Highlights.
- Notes.
- In-book search.
- Reader customization.
- Optional account creation.
- Reading-progress synchronization.
- Annotation synchronization.
- Optional book-file synchronization.
- Privacy and deletion controls.
- Crash and performance monitoring.

### Phase 5 — Play Store beta

Deliver:

- Closed Android testing.
- Low- and mid-range device testing.
- Simple and complex EPUB testing.
- Privacy policy.
- Data safety declaration.
- Account deletion flow.
- Store screenshots and listing.
- Signed Android App Bundle.
- Staged production rollout.

### Phase 6 — Later capabilities

- Text-based PDF import.
- Scanned PDF OCR.
- PDF-to-canonical-book conversion.
- Offline dictionary.
- Offline language detection.
- Offline translation where practical.
- Small on-device model for basic explanations.
- Tablet and foldable optimization.
- Additional translation languages.

---

## 16. MVP boundaries

### Included

- Android.
- Flutter.
- User-uploaded EPUB.
- Local library.
- Swipeable pagination.
- Stable content identity.
- Offline reading.
- Logical reading-position restoration.
- Online AI using the user’s key.
- Context-aware explanation.
- Reader chat.
- Chapter overview.
- Vietnamese translation.
- Original/VN/MIX modes.
- Local generated-content cache.
- Optional synchronization.

### Excluded until later

- PDF.
- OCR.
- DRM-protected books.
- Book marketplace.
- Book sales.
- Fully offline AI.
- iOS.
- Web.
- Desktop.
- Audiobooks.
- Social features.
- Perfect rendering of every EPUB.
- Fixed-page reproduction.

---

## 17. Current technical priority

The first priority is the canonical EPUB reader.

Before investing heavily in AI, translation, or synchronization, the application must reliably support:

1. EPUB import.
2. Ordered canonical content.
3. Stable identifiers.
4. Logical content anchors.
5. Pagination.
6. Position restoration.
7. Text selection.

All later intelligence features depend on this foundation.