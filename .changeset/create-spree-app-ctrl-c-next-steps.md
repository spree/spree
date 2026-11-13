---
"create-spree-app": patch
---

After starting services, pressing Ctrl+C now stops the log stream and prints what to do next: `cd my-store`, then `pnpm run dev` to keep developing, or `pnpm spree stop` to stop the store, which keeps running in Docker. Before, Ctrl+C also ended the `npx` / `pnpm dlx` wrapper, so the setup exited without saying what to do next.
