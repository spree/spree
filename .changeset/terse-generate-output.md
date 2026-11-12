---
"@spree/cli": minor
---

`spree generate` now prints a short summary instead of the generator's full output: the files it created, changed or skipped, anything the generator says on its own, and the next commands to run, such as `spree restart` after an initializer changed, `spree migrate` after a new migration and `spree test` for new specs. Rails boot and Docker output stay hidden unless the generator fails, when everything it printed is shown and the command exits with its exit code. Pass `--verbose` before the generator name for the full output. A generator that asks a question, such as whether to overwrite a file, still shows the question and reads the answer.
