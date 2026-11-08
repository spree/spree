# Documentation site (Mintlify)

These rules apply to the pages under `docs/`, not to `docs/plans/`.

- Don't touch `docs/v5/` — Spree 5 docs are frozen.
- Architectural changes and new models are documented in `docs/developer/`. Fit new material into existing pages before adding one; a new page links to its related pages.
- Show API usage through the SDK and cURL in a `<Tabs>` component; prefer the API to exposing Ruby internals.
- Ruby snippets name their file path relative to `server/` (the default app created by `create-spree-app`).
- Rails commands and rake tasks are shown through the `spree` CLI, with a "Spree CLI / Without CLI" `<Tabs>` pair.
- `docs/api-reference/*.yaml` are generated from the API's integration specs — never edit them by hand.
- Explain what a feature does, why it exists and how to use it, not how it works internally.
