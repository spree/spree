---
"@spree/dashboard": patch
---

Changing the customer of an open order now asks for confirmation first. The dialog says the order moves to the new customer, and, when the previous customer's store credit or gift card is applied, that it is removed and returned to them, so the amount due goes back up.
