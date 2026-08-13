---
'create-spree-app': major
---

Scaffolded apps no longer ship with a known admin password.

Spree 6.0 replaces the seeded `spree@example.com` / `spree123` account with a first-run setup screen, so a new project no longer starts life with credentials that are public knowledge:

- The scaffold summary and the generated README point at first-run setup instead of printing an email and password.
- The first run opens the setup link, where you create the admin account and name the store.
- The exported `DEFAULT_ADMIN_EMAIL` and `DEFAULT_ADMIN_PASSWORD` constants are gone.
