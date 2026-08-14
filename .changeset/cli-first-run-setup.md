---
'@spree/cli': major
---

`spree init` asks who the admin is instead of seeding a known account.

Spree 6.0 stops seeding `spree@example.com` / `spree123`, so the CLI no longer prints or assumes those credentials:

- `spree init` prompts for an admin email and password, or takes `--admin-email` / `--admin-password`. Both are validated before Docker starts, rather than failing minutes into the run, and passing only one is rejected.
- A non-interactive run without those flags (CI, a piped invocation) creates **no admin**. The seed prints a one-time setup link instead, and the summary card shows it — open it to create the first account in the dashboard. `--open` goes straight there.
- Sample data is skipped on that path, since its import needs an admin to own it. Load it after setup with `spree sample-data`.
- `spree dev` names the admin email `spree init` seeded; when no account was seeded it points at the setup link rather than guessing an address.
- The exported `DEFAULT_ADMIN_EMAIL` and `DEFAULT_ADMIN_PASSWORD` constants are gone.

Scripted installs that relied on the old credentials must now pass `--admin-email` and `--admin-password`.
