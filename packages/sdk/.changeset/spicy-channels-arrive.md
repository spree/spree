---
"@spree/sdk": minor
---

Add `client.channel.get()` — returns the channel the client's requests resolve to (API-key binding → `channel` option → store default), including the resolved `storefront_access` posture (`public` | `prices_hidden` | `login_required`) and `guest_checkout`. Gated storefronts can call it before authentication to decide whether to render a sign-in wall. Also exports the `Channel` and `CustomerGroup` types; `customers/me` now includes store-scoped `customer_groups`.
