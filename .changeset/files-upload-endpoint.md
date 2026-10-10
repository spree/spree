---
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": minor
"@spree/dashboard-core": minor
"@spree/dashboard-ui": minor
"@spree/seller-dashboard": minor
---

`directUploads.create()` is replaced by `files.create()` and `files.upload()`, which uploads a file and resolves to a `signed_id` in one call, either straight to storage or in the request itself. The `signed_id` expires after a day. Every parameter that takes one is now named `signed_id` or `<slot>_signed_id` (`avatar_signed_id`, `logo_signed_id`, `attachment_signed_id`, `document_signed_id`, `file_signed_id`, `po_document_signed_id`, …). In `@spree/dashboard-core`, `useDirectUpload` becomes `useFileUpload({ visibility })`, and `signedIdParam` builds the three-state write for an image or document field.
