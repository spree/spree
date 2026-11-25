---
"@spree/dashboard": patch
---

Removing someone from staff, or clearing all their roles, now also refreshes the Staff page's pending invitations. The API revokes that person's other pending invitations for the store, so they leave the list together with the teammate.
