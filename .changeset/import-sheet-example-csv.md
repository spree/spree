---
"@spree/dashboard-core": patch
---

The CSV import sheet now offers a downloadable example file alongside the existing (headers-only) template, so you can see a populated CSV before preparing your own — or import it as-is. The examples are Spree's own sample data, the same files `rake spree:load_sample_data` uses, served through `GET /api/v3/admin/imports/example` and pinned to the installed Spree version so they always match your import schema. Import types with no example file simply omit the link.
