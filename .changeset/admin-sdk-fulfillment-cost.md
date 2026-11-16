---
"@spree/admin-sdk": minor
---

`orders.fulfillments.update` accepts `cost` to set a parcel's delivery cost by hand; no re-quote, rate change or move changes it afterwards, and `cost: null` goes back to the selected delivery rate's price. `Fulfillment` gains `cost_source`, which reads `'manual'` for a hand-set cost.
