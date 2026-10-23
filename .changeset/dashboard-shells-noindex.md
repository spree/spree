---
"@spree/cli": patch
---

The dashboard and seller panel starters now tell search engines not to index them: a `<meta name="robots" content="noindex, nofollow">` in each shell, for a panel served from a static host, alongside the `X-Robots-Tag` header the Rails engine adds when it serves a panel itself.
