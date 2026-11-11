---
"@spree/admin-sdk": patch
"@spree/dashboard": patch
---

Added `sellers.invitations.create`, which invites someone to a seller's team without changing the seller's status. The seller page's team card uses it, so an approved seller can get its first user, and each pending invitation now has a Copy invitation link action.
