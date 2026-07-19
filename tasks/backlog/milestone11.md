# Milestone 11 — Testing and release preparation

## TASK-1101 — Add canonical-model unit tests

**Priority:** P0

Test:

* Stable IDs.
* Sentence offsets.
* Serialization.
* Chapter ordering.
* Text anchors.

---

## TASK-1102 — Add import integration tests

**Priority:** P0

Test:

* Valid EPUB.
* Corrupted EPUB.
* Missing metadata.
* Unsupported DRM.
* Complex chapter structure.
* Failed-import rollback.

---

## TASK-1103 — Add reader integration tests

**Priority:** P0

Test:

* Open and restore position.
* Font-size repagination.
* Rotation.
* Chapter transitions.
* Highlight preservation.

---

## TASK-1104 — Add AI integration tests

**Priority:** P1

Test:

* Valid API key.
* Invalid API key.
* Offline request.
* Rate limit.
* Retry.
* Cancellation.
* Cache hit.

---

## TASK-1105 — Add translation-mode tests

**Priority:** P1

Test:

* Original to VN.
* VN to MIX.
* Missing offline translation.
* Position preservation.
* Annotation preservation.

---

## TASK-1106 — Test low- and mid-range Android devices

**Priority:** P2

Measure:

* EPUB import duration.
* Pagination duration.
* Memory usage.
* Chapter-opening speed.
* Reader swipe smoothness.
* Large-book behavior.

---

## TASK-1107 — Add privacy controls

**Priority:** P2

**Acceptance criteria:**

* Users know selected book text is sent to their chosen AI provider.
* API keys are never logged.
* AI conversations can be deleted.
* Synchronized data can be deleted.
* Account deletion is available when accounts are introduced.
