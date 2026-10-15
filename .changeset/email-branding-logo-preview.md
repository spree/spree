---
"@spree/dashboard": patch
"@spree/admin-sdk": patch
---

The email branding preview now shows a newly uploaded or removed logo before saving, and refreshes after saving. The logo now sits in the Branding section of email settings. `EmailTemplatePreviewParams` accepts `mailer_logo_signed_id`.
