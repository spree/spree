---
"@spree/sdk": patch
---

`resource_type`, `inviter_type` and `invitee_type` on the `Invitation` type now return the API shorthand (`"store"`, `"admin_user"`) instead of the Ruby class name, matching how every other type field on the API is serialized. The TypeScript types are unchanged (`string | null`); only the values differ.
