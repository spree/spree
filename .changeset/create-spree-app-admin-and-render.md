---
"create-spree-app": patch
---

The generated README and the closing summary no longer point at a Rails admin at `/admin`, which Spree 6 does not have; without the React Dashboard, the summary shows the command that adds it. The subscriber example uses `order.placed` rather than the deprecated `order.completed`. The relocated `render.yaml` always builds `server/Dockerfile`, whether the starter's Blueprint was written for this layout or for deploying the starter on its own.
