---
"create-spree-app": patch
"@spree/cli": patch
---

After starting services, pressing Ctrl+C in `create-spree-app` now prints what to do next: `cd` into the project, then `pnpm run dev` to start the store (finishing setup if Ctrl+C interrupted it), or `pnpm spree stop` to stop containers that are still running. Before, Ctrl+C also ended the `npx` / `pnpm dlx` wrapper, so the setup exited without saying what to do next. Every `cd` hint now uses the path the project was created at, such as `projects/my-store`, instead of only its folder name.

`spree dev` and `spree init` now stop the dashboard dev server when the terminal closes or the CLI receives SIGTERM, instead of leaving it running and holding its port.
