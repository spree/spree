---
"create-spree-app": patch
---

After starting services, pressing Ctrl+C now stops the servers and prints the commands to start them again (`cd my-store`, then `pnpm run dev`). Before, Ctrl+C also ended the `npx` / `pnpm dlx` wrapper, so the setup exited without saying what to do next.
