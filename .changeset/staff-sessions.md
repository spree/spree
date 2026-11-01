---
"@spree/dashboard": patch
"@spree/dashboard-ui": patch
"@spree/admin-sdk": patch
"@spree/core": patch
---

The staff settings page shows each member's status (active, locked or deactivated) and when they were last active. A new "View details" action opens a sheet with when they joined, who invited them and their signed-in sessions, each with its browser, IP address and last use. The admin SDK types gain `status`, `last_active_at`, the `inviter` and `sessions` expands, and the `Session` and `AdminUserStatus` types; `@spree/dashboard-ui` adds `BrowserIcon`.
