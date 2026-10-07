---
"@spree/dashboard": minor
"@spree/dashboard-core": minor
"@spree/dashboard-ui": minor
---

Added an email template editor under Settings → Emails → Templates. Merchants edit the emails customers receive, the email layout and shared blocks with a code editor that suggests variables and marks problems by line, next to a live preview (desktop and mobile, email and plain text). Edits save as drafts and go live when published; drafts can be discarded, templates reverted to Spree's default, test emails sent to yourself, and earlier versions restored from the history. A banner shows when a Spree upgrade changed a default the store customized, with a side-by-side comparison. The email settings page gains a Branding card for the colors and font of customer emails, with a preview. `@spree/dashboard-ui` adds a `CodeEditor` (deep import `@spree/dashboard-ui/ui/code-editor`) and a `useDebouncedValue` hook; `@spree/dashboard-core` adds the `EmailTemplate` permission subject.
