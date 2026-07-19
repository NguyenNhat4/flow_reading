# Decision Log

## Fix OpenAI Responses API JSON Schema Structure

- **What:** Wrap `name`, `strict`, and `schema` fields under a nested `"json_schema"` object inside the `"format"` block of OpenAI Responses API requests.
- **Why:** The official OpenAI Responses API expects a nested structure instead of flat fields. The incorrect flat structure caused the API to reject requests with 400 Bad Request, leading to the "AI Provider could not complete the request" error in the app.
- **When:** February 2026
