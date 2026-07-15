# TASK-004 — Create shared error model

**Milestone:** Milestone 0 — Project foundation

**Priority:** P0 — Required for the first working reader

Create application failures for:

* Invalid EPUB.
* Unsupported DRM.
* File-system failure.
* Database failure.
* Network failure.
* Invalid API key.
* AI provider failure.

## Acceptance criteria

* UI code does not inspect raw database or HTTP exceptions.
* Every failure has a readable user-facing message.
