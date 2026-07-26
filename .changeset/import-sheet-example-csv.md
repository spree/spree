---
"@spree/dashboard-core": patch
---

The CSV import sheet now links to a downloadable example file alongside the existing (headers-only) template, so you can see a populated CSV before preparing your own — or import it as-is. The examples are Spree's own sample data, the same files `rake spree:load_sample_data` uses, so they always match the current import schema. Import types with no example file simply omit the link.
