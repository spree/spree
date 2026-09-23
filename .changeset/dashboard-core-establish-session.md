---
"@spree/dashboard-core": minor
---

`useAuth()` now returns `establishSession`, which signs in with a `{ token, user }` session a host app obtained from a sign-in endpoint of its own (one that also sets the refresh cookie). The session starts without a page reload and is refreshed like one from `login`.
