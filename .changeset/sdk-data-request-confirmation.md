---
"@spree/sdk": minor
"@spree/admin-sdk": patch
"@spree/dashboard": patch
---

A customer's own data request now waits for confirmation from the account's email address. `client.customer.dataRequests` lists, reads and opens requests, and `create` takes a `redirect_url` for the page the emailed link opens. `client.dataRequests.confirm(token)` confirms one from that page, and `client.dataRequests.get(token)` reads it, with the download link once the export is ready. `DataRequestStatus` gains `awaiting_confirmation` and `lapsed`. The dashboard's email editor lists the new confirmation email.
