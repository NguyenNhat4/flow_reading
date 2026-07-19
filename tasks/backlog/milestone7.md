# Milestone 7 — Translation

## TASK-701 — Define translation model

**Priority:** P1

Associate each translation with:

* Source sentence ID.
* Target language.
* Translated text.
* Provider and model.
* Prompt version.
* Creation time.

**Acceptance criteria:**

* Translation remains linked to the source sentence.
* Translations do not create a separate translated-book hierarchy.

---

## TASK-702 — Implement sentence translation

**Priority:** P1

**Acceptance criteria:**

* Surrounding paragraph context is included.
* Source tone and intent are requested.
* Translation is cached locally.
* Vietnamese is the initial target language.

---

## TASK-703 — Implement Original mode

**Priority:** P1

**Acceptance criteria:**

* Only source content is displayed.
* No AI translation is required.
* Reading remains fully available offline.

---

## TASK-704 — Implement VN mode

**Priority:** P1

**Acceptance criteria:**

* Vietnamese translation replaces source text where available.
* Missing offline translation falls back to original text.
* Missing translation state is clearly explained.

---

## TASK-705 — Implement MIX mode

**Priority:** P1

**Acceptance criteria:**

* Every source sentence is followed by its translation.
* Sentence pairs remain correctly associated.
* Layout remains readable.

---

## TASK-706 — Preserve position between language modes

**Priority:** P1

**Acceptance criteria:**

* The user remains near the same source sentence.
* Switching modes triggers safe repagination.
* Highlights and notes remain attached to source anchors.

---

## TASK-707 — Implement per-book glossary

**Priority:** P2

**Acceptance criteria:**

* Glossary entries are associated with a book.
* Established terminology is included in later translation requests.
* Users can inspect and edit glossary terms.
