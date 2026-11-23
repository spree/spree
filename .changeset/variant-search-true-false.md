---
"@spree/dashboard": patch
---

Variant pickers wait for three characters before searching and say so, since a shorter variant search finds nothing. Searching for "1", "t" or "true" in a variant picker, or in the order and returns lists, no longer fails.
