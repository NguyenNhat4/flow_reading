# Decision Log

## Fix OpenAI Responses API JSON Schema Structure & Add Console Logging

- **What:** Reverted the request format back to flat fields (e.g., `name`, `strict`, `schema` placed directly under `text.format`) and added robust console log tracking for all API errors/exceptions in `OpenAiProvider`.
- **Why:** The OpenAI Responses API specifications require a flat structure for `text.format` configuration parameters (e.g. `text.format.name`), unlike the top-level `response_format` configuration parameter used in the legacy Chat Completions API. Having added diagnostic printing allowed us to see that the nested structure was rejected with `Missing required parameter: 'text.format.name'`.
- **When:** February 2026

## Resolve Reasoning Token Budget Exhaustion on OpenAI Responses API

- **What:** Increased `maxOutputTokens` value from tight constraints (e.g., `650`) to `16000` for all prompt templates in `lib/domain/use_cases/ai_prompt_registry.dart`. Additionally, updated `OpenAiProvider.complete()` to accept both `'completed'` and `'incomplete'` statuses, provided the extracted `text` is non-empty.
- **Why:** Advanced reasoning-capable models (such as `gpt-5-nano` or similar o-series models) consume a large amount of reasoning tokens (which are part of the total output token budget) before producing the visible response text. This caused the API response to terminate with `"status": "incomplete"` and `"reason": "max_output_tokens"` before any actual visible text could be returned, throwing an `AiProviderFailure`. Increasing the budget allows adequate room for reasoning, and allowing `"incomplete"` status gracefully handles edge cases.
- **When:** February 2026
