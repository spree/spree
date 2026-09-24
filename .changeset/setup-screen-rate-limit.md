---
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

The setup screen no longer says an installation is already set up when it simply could not check. A rate-limited check shows "Too many attempts" and a failed one shows "Couldn't check setup", each with a retry button; "Setup is not available" now appears only when the server confirms setup is done. The setup status is also no longer re-checked every time the browser tab regains focus.
