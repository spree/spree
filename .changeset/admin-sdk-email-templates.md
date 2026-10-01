---
"@spree/admin-sdk": minor
---

Added `client.emailTemplates` for editing a store's customer email templates, email layout and shared partials: list and read them per language, save and discard drafts, preview with sample data, send a test email to yourself, publish, revert to Spree's default, and list or restore published revisions. Also added `EmailTemplate`, `EmailTemplateDraft`, `EmailTemplatePreview` and `EmailTemplateRevision`, and `Email*` types (`EmailOrder`, `EmailStore`, ...) describing the data each customer email template renders with.
