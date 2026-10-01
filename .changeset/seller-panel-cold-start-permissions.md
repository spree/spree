---
"@spree/dashboard-core": patch
"@spree/seller-dashboard": patch
---

Fixed the seller panel opening with an empty sidebar when a seller returned with a live session but no remembered seller, for example after the browser cleared site storage. The panel now loads the seller's permissions once it knows which seller is active.
