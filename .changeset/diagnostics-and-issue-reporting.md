---
"@spree/cli": patch
"@spree/admin-sdk": patch
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

Added an anonymised diagnostics report for bug reports: `spree info` in the CLI, Settings → System info and Send feedback in the dashboard's account menu, also offered when the server answers with an error, and `adminClient.diagnostics.get()` in the Admin SDK. The dashboard build records its installed `@spree/*` package versions and adds them to the report. Every detail page that passes its record and endpoint to `PageHeader` now gets View as JSON, with Copy JSON and Copy as curl, including the seller panel. A developer inspector, opened from the user menu or with Ctrl/Cmd+Shift+D, lists the dashboard's recent API requests with their request IDs; `sdk-core` and `@spree/admin-sdk` gain an optional `onRequestComplete` option to feed it. The admin client gains `getStore()`, and admin file downloads now send the store header.
