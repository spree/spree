---
"create-spree-app": patch
---

Fix the generated project's CI workflow when the Rails app lives under `backend/`. The relocated `backend-ci.yml` now points `ruby/setup-ruby` and the `bin/rails`/`bundle` steps at the `backend/` subdirectory, so `ruby/setup-ruby` finds `.ruby-version` instead of failing with "input ruby-version needs to be specified".
