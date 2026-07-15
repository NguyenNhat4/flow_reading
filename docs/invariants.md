# Invariants

These rules must never be violated.

## Content

1. Keep the original EPUB unchanged.
2. Parsed content is stored separately.
3. Failed imports must not damage existing books.
4. Do not bypass DRM.

## Stable identity

5. Durable data references canonical source content.
6. Stable IDs must not depend on page number.
7. Stable IDs must survive app restart and repagination.
8. Original, VN, and MIX modes share the same source identity.

## Pagination

9. Visual pages are temporary layout results.
10. Page boundaries may be deleted and rebuilt.
11. Page numbers must not identify reading progress or annotations.
12. Repagination must restore the closest logical source position.

## Reading state

13. Reading progress uses a content anchor.
14. Save progress when the reader closes or the app backgrounds.
15. Layout changes must preserve logical position.

## Annotations

16. Bookmarks, highlights, and notes attach to source anchors or ranges.
17. Annotations must survive repagination.
18. Annotations remain linked to original source content.

## Offline

19. Importing and reading local books requires no account.
20. Core reading must work without internet.
21. Online-feature failure must not break the reader.
22. Cached AI and translation content may be shown offline.

## AI

23. AI is optional.
24. Never ship a developer-owned production API key.
25. Store user keys in secure platform storage.
26. Reader features must not depend directly on one AI provider.
27. AI context must use source anchors, not page numbers.
28. Send only relevant context.
29. Failed requests must not be stored as successful results.

## Translation

30. Translation attaches to stable source ranges.
31. Translation must use surrounding context when available.
32. Translation glossary is book-specific.
33. Missing offline translation must fall back to original text.

## Sync

34. Synchronization is optional.
35. Local reading must work without sync.
36. Disabling sync must not delete local data.
37. Conflicting note content must preserve both versions.
