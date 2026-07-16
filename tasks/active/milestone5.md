
# Milestone 5 — AI foundation

## TASK-501 — Implement secure API-key storage

**Status:** Complete

**Priority:** P1

**Acceptance criteria:**

* API keys use Android-protected credential storage.
* Keys are never stored in logs.
* Keys are never stored in the normal database.
* No developer-owned API key exists in the application.

---

## TASK-502 — Define AI provider interface

**Status:** Complete

**Priority:** P1

Create one common interface for:

* Key validation.
* Completion.
* Streaming.
* Provider error mapping.

**Acceptance criteria:**

* UI code does not depend on a provider SDK.
* Product prompts do not live inside provider implementations.
* Only one provider is implemented initially.

---

## TASK-503 — Implement first AI provider

**Status:** Complete

**Priority:** P1

**Acceptance criteria:**

* A valid key can be verified.
* Invalid keys produce `InvalidApiKeyFailure`.
* Rate limits and connectivity errors are handled.
* Streaming requests can be cancelled.

---

## TASK-504 — Implement context builder

**Priority:** P1

Build an AI context package containing:

* Selected text.
* Containing sentence.
* Containing paragraph.
* Nearby paragraphs.
* Chapter title.
* Current position.
* Relevant earlier passages.
* Recent conversation messages.

**Acceptance criteria:**

* Context respects a maximum size budget.
* Selected text has highest priority.
* Duplicate passages are removed.
* Every included passage retains its stable anchor.

---

## TASK-505 — Implement prompt templates

**Priority:** P1

Create versioned prompts for:

* Word explanation.
* Passage explanation.
* Grammar explanation.
* Summary.
* Translation.
* Chapter overview.
* Chat.

**Acceptance criteria:**

* Every prompt has a version number.
* Prompts require the model to distinguish facts from interpretation.
* Prompts request structured output where useful.

---

## TASK-506 — Implement AI artifact cache

**Priority:** P1

Cache:

* Explanations.
* Translations.
* Chapter overviews.
* Summaries.

**Acceptance criteria:**

* Cache keys include content hash and prompt version.
* Cached responses are available offline.
* Changing a prompt version does not silently reuse incompatible output.

---

## TASK-507 — Add word explanation

**Priority:** P1

Return:

* Contextual meaning.
* Part of speech.
* Reason it is used in the passage.
* Simpler paraphrase.
* At least two examples.
* Ambiguity warning where needed.

**Acceptance criteria:**

* Response is grounded in the selected sentence.
* The user remains on the reader screen.
* The result is cached locally.

---

## TASK-508 — Add passage explanation

**Priority:** P1

**Acceptance criteria:**

* The passage remains visible while loading.
* The request can be cancelled.
* The explanation preserves the original meaning.
* Failed requests provide Retry.

---

## TASK-509 — Add grammar explanation

**Priority:** P2

**Acceptance criteria:**

* Only grammar relevant to understanding the passage is explained.
* The response does not become a generic grammar lesson.
* Results are cached.

---
