---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
---

The Add payment dialog lists only the saved cards the chosen payment method can charge. Adding, capturing or voiding a payment now says why when the gateway refuses it, and the order refreshes either way, so a refused payment shows as failed without reloading; a refused capture from the dialog closes it rather than inviting a second payment. `useResourceMutation` gains `refreshOnError` for actions whose refusal still changes the record.
