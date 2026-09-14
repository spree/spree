---
"@spree/dashboard-ui": patch
"@spree/dashboard": patch
---

Keep list and quote toolbar buttons working after the TipTap 3.31 pin. Two copies of prosemirror-model made wrap throw, so the bullet button left a paragraph; pinning one version and running the command on pointerdown restores lists. Enter still persists as its own paragraph.
