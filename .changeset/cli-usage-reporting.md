---
"@spree/cli": minor
"create-spree-app": minor
---

The CLI and `create-spree-app` report which setup commands run and whether they succeed, so the Spree team can see where new projects get stuck. Only lifecycle commands run from a terminal are reported, in the background after they finish, with a one-time notice. Turn it off with `spree telemetry disable`, `SPREE_TELEMETRY_DISABLED=1` or `DO_NOT_TRACK=1`; CI runs are never reported.
