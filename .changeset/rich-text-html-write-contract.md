---
'@spree/admin-sdk': minor
'@spree/cli': patch
---

Rich text is written as `*_html`.

Spree 6.0 stores rich text as sanitized HTML in plain text columns instead of Action Text. Reads are unchanged — `description` is still plain text and `description_html` still holds the markup — but the **write** params are renamed, so reading and writing now use the same field name.

- `description` → `description_html` on product, category and collection create/update.
- `internal_note` → `internal_note_html` on order and customer create/update.
- `internal_note_html` is now readable on `Order`, and `internal_note` (plain text) on `Customer`. Previously the order serializer returned only plain text and the customer serializer only HTML.

A write that still passes the plain field name **succeeds with 200 and stores nothing** — the parameter is no longer permitted, and Rails drops unpermitted parameters rather than rejecting them, so there is no 422 to alert you. Audit any integration writing descriptions or internal notes.
