---
"@spree/dashboard-ui": patch
"@spree/dashboard": patch
"@spree/dashboard-core": patch
---

Keep list and quote toolbar buttons working after the TipTap 3.31 pin. Two copies of prosemirror-model made wrap throw; pinning one version (and deduping it in the Vite plugin) restores the stock TipTap commands. Enter still persists as its own paragraph.
