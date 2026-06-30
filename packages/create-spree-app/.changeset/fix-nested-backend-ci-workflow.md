---
"create-spree-app": patch
---

Fix and tidy the generated project's CI for the nested `backend/` layout. The relocated `backend-ci.yml` now points `ruby/setup-ruby` and the `bin/rails`/`bundle` steps at `backend/`, so `ruby/setup-ruby` finds `.ruby-version` instead of failing with "input ruby-version needs to be specified". The starter's `release.yml` (which publishes the official Spree image) and its standalone `README.md` are no longer carried into the generated project.
