---
"@spree/sdk": patch
---

Expose `request` method on the client for calling custom API endpoints. Paths are relative to `/api/v3/store` and use the same auth headers, retry logic, and locale/currency defaults as built-in resources.

```ts
const client = createClient({ baseUrl: '...', publishableKey: '...' })
const brands = await client.request<PaginatedResponse<Brand>>('GET', '/brands')
```
