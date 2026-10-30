---
"@spree/dashboard-ui": patch
---

`@spree/dashboard-ui` no longer installs the shadcn CLI and its roughly 300 dependencies in host apps. The one stylesheet it used from that package now ships inside `@spree/dashboard-ui`, so the dashboard looks exactly the same.
