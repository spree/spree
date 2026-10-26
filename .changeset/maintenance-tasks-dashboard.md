---
"@spree/dashboard": minor
---

Added Settings → Maintenance tasks. The Upgrade tab lists the data steps a Spree upgrade needs, in order, and runs them one at a time; a store with nothing to convert is told it is up to date. The History tab records every run, from the dashboard or the command line, and each run opens a sheet with its progress, results and a Cancel button. The page is hidden when `SPREE_MAINTENANCE_TASKS_DASHBOARD_ENABLED=false`.
