# Technical dependency decisions

Reviewed 2026-07-14. Versions listed as “later” are decisions, not current
dependencies; they are added only in the milestone that uses them.

| Capability | Selection | License | Android / maintenance assessment | Decision |
|---|---|---|---|---|
| EPUB ZIP parsing | `archive` 4.0.9 | MIT | Pure Dart, active, all Flutter platforms; v4 prioritizes file I/O. | Use with explicit path traversal, size, encryption, and ZIP-bomb checks. Avoid a monolithic EPUB model that would couple domain IDs to a parser. |
| EPUB XML | `xml` 7.0.1 | MIT | Pure Dart, maintained, standards-oriented. | Parse container, OPF, NCX, and navigation documents behind `CanonicalBookParser`. |
| HTML/CSS parsing | `html` 0.15.6 plus a strict importer allowlist | BSD-style Dart SDK license | Mature Dart Tools package. | Sanitize to canonical blocks and supported inline styles. Scripts, external URLs, and arbitrary CSS never reach rendering. |
| Rendering | Flutter `Text`, `RichText`, and image widgets | Flutter BSD-3-Clause | First-party and Android compatible. | Render canonical content natively. A WebView is rejected for the prototype because it complicates stable word hit-testing, pagination, and untrusted markup isolation. |
| SQL / FTS | `sqflite` 2.4.3 and SQLite FTS5 | BSD-2-Clause | Mature Android plugin; transactions, migrations, and background DB execution. | Normalized stable content plus JSON snapshots; FTS table supports future context/search. `sqflite_common_ffi` 2.4.2 is test-only. |
| File picking | `file_picker` 11.0.2 | MIT | Maintained Android Storage Access Framework integration and extension filtering. | Milestone 1 selects EPUB candidates; content is copied immediately into app-private storage. |
| App-private paths | `path_provider` 2.1.5 + `path` 1.9.1 | BSD-3-Clause | Flutter-team/community packages, broadly used on Android. | Store database and untouched EPUB copies under application support storage. |
| Stable hashing | `crypto` 3.0.6 | BSD-3-Clause | Dart team package, pure Dart. | SHA-256 source fingerprints and deterministic content IDs. |
| State / DI | `flutter_riverpod` 3.3.2 | MIT | Actively maintained and Android-agnostic. | Explicit, overrideable providers; async state has loading/error primitives. Avoid code generation for the foundation. |
| Routing | `go_router` 17.3.0 | BSD-3-Clause | Flutter-published, feature-complete and maintained. | Declarative routes and future deep links to stable book locators. |
| Logging | `logging` 1.3.0 | BSD-3-Clause | Dart ecosystem standard, platform-neutral. | Central JSON formatter and redaction; no remote telemetry in Milestone 0. |
| Secure storage (Milestone 2) | `flutter_secure_storage` 10.3.1 | BSD-3-Clause | Active; current Android implementation requires API 23 and uses RSA-OAEP/AES-GCM defaults. Migration/backup behavior needs device tests. | Store only user-owned provider secrets. Add with AI infrastructure, not Milestone 1. |
| Connectivity (Milestone 2) | `connectivity_plus` | BSD-3-Clause | Active Flutter Community plugin. Connectivity type does not prove internet reachability. | Use only as a hint; network requests remain authoritative and cached reading never depends on it. |
| Networking (Milestone 2) | `dio` | MIT | Widely used and supports cancellation, streaming, interceptors, and timeouts. | Wrap behind the AI provider adapter; add only when online AI begins. |
| Serialization codegen (later) | `json_serializable` 6.14.0 | BSD-3-Clause | Google-published, maintained; adds build-runner/analyzer coupling. | Foundation uses reviewed manual serializers. Re-evaluate codegen when model churn settles. |

## Packages intentionally not added

Secure storage, connectivity, networking, and serialization generators are not
needed by Milestone 1 and therefore remain out of `pubspec.yaml`. An EPUB-specific
package is also not used: composing `archive`, `xml`, and `html` gives validation
control, sanitizer ownership, and canonical-model independence.
