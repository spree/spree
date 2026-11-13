---
"create-spree-app": patch
---

After starting services, pressing Ctrl+C now stops the servers and opens a shell inside the new project, so the next `pnpm dev` runs without a `cd` first. Type `exit` to return to the directory you started from. On Windows or without an interactive terminal, Ctrl+C behaves as before.
