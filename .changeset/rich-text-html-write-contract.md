---
'@spree/admin-sdk': patch
'@spree/cli': patch
---

Rich-text fields read as plain text plus HTML.

Spree 6.0 stores rich text as sanitized HTML in plain text columns instead of Action Text. The write params are unchanged — `description` and `internal_note` still take the value, and that value is HTML.

What changed is the read side:

- `internal_note_html` is now readable on `Order`, and `internal_note` (plain text) on `Customer`. Previously the order serializer returned only plain text and the customer serializer only HTML; both now return the pair.
- `description` returns tag-stripped plain text, with the markup under `description_html`. Hydrate an editor from `description_html`, not `description`.

The field stores HTML, so send markup — a plain-text value with newlines in it renders as one run-on line.
