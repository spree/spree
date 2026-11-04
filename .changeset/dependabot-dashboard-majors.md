---
"create-spree-app": patch
---

New projects get a Dependabot config that opens Admin Dashboard and Seller Panel major updates as separate PRs instead of in the weekly group, so one breaking release no longer blocks the minor and patch bumps. Major `@types/node` updates are skipped, since they follow the Node version the app runs on.
