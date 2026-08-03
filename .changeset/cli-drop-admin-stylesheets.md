---
'@spree/cli': major
---

Dropped the admin stylesheet steps from `spree dev` and `spree eject`.

The legacy Rails admin (`spree_admin`) is removed in Spree 6.0, and with it the `spree:admin:tailwindcss:build` and `spree:admin:tailwindcss:watch` rake tasks these steps invoked. On an ejected project, `spree dev` no longer compiles `spree/admin/application.css` before boot or starts the Tailwind watcher, and `spree eject` no longer compiles it during setup.

Admin UI now ships as the React dashboard, which builds through Vite — run it with `spree dev` (co-runs the dashboard dev server) or `spree add dashboard`. Projects ejected before this release can delete the orphaned `backend/app/assets/builds/spree/admin/` directory.
