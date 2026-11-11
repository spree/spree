---
"@spree/dashboard-core": patch
---

`AddressFormDialog` asks before discarding unsaved changes, whether it is closed with Cancel, Escape or by clicking outside, and its Save waits for a change when editing an address that is already filled in. A blank address stays saveable, so pressing Save shows what is still missing.
