---
"@spree/admin-sdk": minor
---

Added maintenance task runs and upgrade steps. `upgradeSteps.list()` returns the data steps a Spree upgrade still needs, in the order they must run, each with its last run. `maintenanceTaskRuns` lists, gets and starts runs, and `maintenanceTaskRuns.cancel()` stops one. Runs belong to the whole installation, and a task is named by its short name (`capture_methods`), never a Ruby class name.
