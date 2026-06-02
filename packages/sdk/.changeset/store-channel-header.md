---
'@spree/sdk': patch
---

Add sales-channel selection to the Store SDK via the `X-Spree-Channel` header.

- `createClient({ channel: 'pos' })` — set a client-level default
- `client.setChannel('wholesale')` — sticky setter, mirrors `setLocale` / `setCurrency` / `setCountry`
- `await client.products.list({}, { channel: 'pos' })` — per-request override

The value can be either a channel `code` (e.g. `online`, `pos`, `wholesale`) or the prefixed ID (`ch_…`); `code` is preferred. Backend resolution stays at `Spree::Api::V3::ChannelResolution`: a matching header picks the channel for the request, otherwise the store's default channel applies.
