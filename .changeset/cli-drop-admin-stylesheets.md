---
'@spree/cli': major
---

Dropped the legacy Rails admin from the CLI.

`spree_admin` is removed in Spree 6.0, so the CLI no longer references it:

- `spree dev` and `spree eject` no longer compile the admin Tailwind stylesheet or start its watcher — the `spree:admin:tailwindcss:build` and `spree:admin:tailwindcss:watch` rake tasks went with the gem.
- `spree dev`, `spree init` and `spree open` no longer point at `http://localhost:<port>/admin`, which now 404s. With a dashboard app present they open its Vite dev server; without one they open the store, and the summary card says to run `spree add dashboard`.

Admin UI now ships as the React dashboard. Run it with `spree dev` (co-runs the dashboard dev server) or add it with `spree add dashboard`. Projects ejected before this release can delete the orphaned `backend/app/assets/builds/spree/admin/` directory.
