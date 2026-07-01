---
"@spree/cli": patch
---

Compile the admin dashboard stylesheet on ejected projects. Ejecting bind-mounts `./backend` over the image's precompiled `app/assets/builds`, and the dev stack never runs `assets:precompile`, so `spree/admin/application.css` was missing and every admin page 500'd. `spree eject` now compiles it, and `spree dev` compiles it if missing and then runs the Tailwind watcher so admin edits recompile live.
