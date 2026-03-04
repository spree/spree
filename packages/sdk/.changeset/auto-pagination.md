---
"@spree/sdk": patch
---

Added auto-pagination support via `AsyncIterableList`. Paginated list methods now support `for await...of` to iterate through all pages automatically, while remaining backward compatible with `await` for single-page results.
