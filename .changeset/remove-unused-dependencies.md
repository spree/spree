---
"@spree/dashboard": patch
"@spree/dashboard-ui": patch
"@spree/seller-dashboard": patch
"@spree/cli": patch
---

Removed dependencies the packages no longer use, so installs are smaller. `@spree/dashboard` no longer lists `next-themes` or its own copies of the packages `@spree/dashboard-ui` already brings. `@spree/seller-dashboard` drops `@dnd-kit` and `lucide-react`, and `@spree/dashboard-ui` drops the unused TipTap bubble and floating menu extensions. Nothing changes for host apps or plugins.
