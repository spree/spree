---
"@spree/dashboard-ui": patch
---

`ReturnReceiveDialog` takes a resellable and a not-resellable count per line, so one line can be received in parts. Its `quantity` is the units still to arrive, and `onSubmit` names a split line twice. Added `receiptItems()`, which builds those rows.
