# Decision Log

## Fix OpenAI Responses API JSON Schema Structure & Add Console Logging

- **What:** Reverted the request format back to flat fields (e.g., `name`, `strict`, `schema` placed directly under `text.format`) and added robust console log tracking for all API errors/exceptions in `OpenAiProvider`.
- **Why:** The OpenAI Responses API specifications require a flat structure for `text.format` configuration parameters (e.g. `text.format.name`), unlike the top-level `response_format` configuration parameter used in the legacy Chat Completions API. Having added diagnostic printing allowed us to see that the nested structure was rejected with `Missing required parameter: 'text.format.name'`.
- **When:** February 2026
