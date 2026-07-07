---
"create-spree-app": patch
---

Relocate the generated project's Render Blueprint (`render.yaml`) to the repository root and add `rootDir: backend` to every buildable service. In the wrapper layout the Rails app lives under `backend/`, so a Blueprint left in that subdirectory is invisible to Render and, without `rootDir`, its services build from the wrong directory — the deploy fails. The commented-out worker template is adjusted too, so uncommenting it still deploys correctly. Managed services (Redis, database) are left untouched.
