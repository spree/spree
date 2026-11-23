---
"@spree/dashboard": patch
---

A purchase order unit cost typed with a comma ("3,80") is read as 3.80 in every browser. It was a number input, which Safari in English read as 380, saving the draft at 100 times the cost; it is now read in the admin's own format, like the store credit and price editors.
