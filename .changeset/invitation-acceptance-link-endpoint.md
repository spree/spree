---
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

Invitation listings no longer include `acceptance_url`, because the link carries the token that accepts the invitation. Fetch it on demand with `invitations.acceptanceLink(id)` (and `sellers.invitations.acceptanceLink(sellerId, id)` in the Admin SDK), which needs write access. The "Copy invitation link" actions in the dashboard and the seller panel now use it.
