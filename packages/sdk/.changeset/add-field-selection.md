---
"@spree/sdk": patch
---

Added `fields` parameter support for field selection. Pass `fields: ['name', 'slug', 'price']` to `list` and `get` methods to receive only specific fields in the response. The `id` field is always included. Omit `fields` to return all fields (default behavior).
