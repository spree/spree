---
"@spree/sdk": patch
---

Added `ListResponse<T>` type for non-paginated list endpoints (countries, currencies, locales, markets). `PaginatedResponse<T>` now extends `ListResponse<T>`.
