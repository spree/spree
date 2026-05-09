---
'@spree/admin-sdk': minor
---

Admin CSV exports — bring back filtered CSV downloads of products, orders, customers, etc. that the legacy Rails admin supported.

- New `client.exports` resource with `list / get / create / delete`.
- New `ExportCreateParams` / `ExportType` request types and `Export` entity type.
- `Export.download_url` is the path to a server-side download endpoint (`GET /api/v3/admin/exports/:id/download`) that 303s to a freshly-signed ActiveStorage URL — assign it to `window.location.href` to trigger the download.
- `Export.done` flips to `true` once the background job finishes generating and attaching the CSV; clients should poll `get(id)` until then.
- `search_params` accepts the same Ransack predicate shape (`{ name_cont, price_gt, … }`) used on list endpoints, so toolbar filter state can be forwarded as-is.
