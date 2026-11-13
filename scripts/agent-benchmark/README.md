# Agent benchmark

Runs coding agents against real tasks on a fresh `create-spree-app` project and
measures where they stumble. The plan behind it, and how findings turn into
fixes, is `docs/plans/6.1-agent-benchmark.md`.

## Requirements

- Docker, running
- Node.js 22 or later
- The agent CLI you want to measure, signed in: `claude` (Claude Code), and
  optionally `codex` or `cursor-agent`
- A few gigabytes of disk and an idle Spree port: each run starts its own
  containers, one run at a time

Nothing to install: the scripts use Node's standard library only.

## Run it

```bash
# Every task once with Claude Code
node scripts/agent-benchmark/run.mjs

# One task, five times, keeping each project for inspection
node scripts/agent-benchmark/run.mjs --task cart-quantity-limit --repeat 5 --keep

# Another agent or model
node scripts/agent-benchmark/run.mjs --agent codex
node scripts/agent-benchmark/run.mjs --model claude-sonnet-4-6
```

| Option | Default | Meaning |
| --- | --- | --- |
| `--task` | `all` | Task ids, comma-separated (file names in `tasks/`) |
| `--agent` | `claude` | `claude`, `codex`, `cursor`, `baseline` (changes nothing; every task should fail) or `reference` (applies the task's hand-written solution; every task should pass). The last two calibrate the checks |
| `--repeat` | `1` | Runs per task |
| `--model` | agent default | Passed to the agent CLI |
| `--out` | a new folder under the system temp dir | Where results go |
| `--image-tag` | `latest` | `SPREE_VERSION_TAG` for the project, to measure another Spree image |
| `--dev-image` | none | An image to run the ejected project on instead of building `server/Dockerfile`'s dev stage, for machines that cannot reach the Debian mirrors. See below |
| `--create-command` | `npx --yes create-spree-app@latest` | How to scaffold, e.g. `node /path/to/spree/packages/create-spree-app/dist/index.js` to test an unreleased scaffold |
| `--keep` | off | Keep the project and its containers after the run |

Agents run with permission prompts off (`--dangerously-skip-permissions` and
equivalents), inside a throwaway directory. Run the benchmark on a machine
where that is acceptable.

## What a run does

1. Scaffolds a project with `create-spree-app --no-start`, then runs
   `spree init` with a generated admin account. The harness mints its own
   publishable key and `write_all` secret key; the agent never sees them.
2. Commits the scaffold to a local git repository.
3. Runs the agent once, headless, with the task prompt. No follow-up turns.
4. Saves the agent's diff, restarts the app and runs the task's acceptance
   check. If the agent ejected the project, the app now runs on a new
   database, so the harness mints its keys again there first.
5. Removes the containers, volumes and project, unless `--keep` is given.

The platform evaluation task skips steps 1, 2 and 5: it runs in an empty
directory and reads `ANSWER.md`.

Each run writes a folder `<task>--<agent>--<n>/` in the results directory:

| File | Contents |
| --- | --- |
| `prompt.txt` | The prompt the agent got |
| `transcript.jsonl` | The agent's full event stream |
| `stderr.log` | The agent CLI's stderr |
| `diff.patch` | Everything the agent changed |
| `acceptance.json` | `{ passed, details }` from the check |
| `meta.json` | Agent, model, timings, exit code, harness errors |
| `ANSWER.md` | The evaluation task's answer |

## Score it

`run.mjs` scores the results when it finishes. To score again, for example
after changing the scorer:

```bash
node scripts/agent-benchmark/score.mjs /path/to/results
```

This writes `report.json` and `report.md`. The Markdown report has a summary
row per task and agent, the removed APIs agents called, and each run's
stumbles with an excerpt of the tool call or output behind it. Start reading
transcripts from those excerpts.

| Metric | Meaning |
| --- | --- |
| Passed | The acceptance check passed |
| Clean | Passed, the agent did not error, and no removed-API hint, deprecation failure or gem source read |
| Model calls | Distinct model responses |
| Tool calls | Tool uses, also by tool name in `report.json` |
| Tool output | Characters of tool results, shown in KB |
| Gem reads | Reads or searches of installed Spree gem source |
| Package reads | Reads of `node_modules/@spree/*` other than `@spree/docs` |
| Docs lookups | Reads of `@spree/docs`, `spreecommerce.org/docs`, or Spree docs MCP calls |
| Removed APIs | `Spree X.Y removed …` hints in tool output |
| Legacy code | Writes and edits containing Spree 4 and 5 idioms |
| Deprecation failures | `ActiveSupport::DeprecationException` in tool output |
| Direct commands | `bin/rails`, `bundle exec`, `rspec` or `docker compose` run outside the Spree CLI |
| Time, cost | From the agent's final result event |

Codex transcripts are read best-effort: commands, file changes and token
usage, but no cost.

## Add a task

Add a file to `tasks/` that default-exports:

```js
export default {
  id: 'my-task',               // matches the file name
  title: 'One line',
  project: { storefront: false }, // or null to run in an empty directory
  timeoutMinutes: 30,
  prompt: `What a developer would ask, without naming the Spree API to use.`,
  check: async ({ projectDir, workDir, port, keys, admin }) => ({ passed: true, details: '…' }),
}
```

Checks that test Ruby code use `runAcceptanceSpec` from `lib/project.mjs`:
it copies a hidden spec into the project, runs it with `spree test`, and
removes it again. Checks that test behaviour over HTTP use `apiClient`.

Before relying on a new task, calibrate it: confirm the check fails on the
untouched scaffold (`--agent baseline`) and passes on a solution written by
hand (`--agent reference`).

A task's reference solution lives in `tasks/<id>/reference/`: `files/` is
copied over the project (or the empty directory of a task without one), then
`apply.sh`, if there is one, runs from there. It uses the Spree CLI the way an
agent would: `spree eject`, `spree migrate`, `spree test`.

## Without the Debian mirrors

Ejecting builds the starter's `dev` image, which installs Debian packages.
Where `deb.debian.org` is unreachable, build a stand-in once from a scaffolded
project's `server/` directory and pass it with `--dev-image`:

```bash
docker build -t spree-bench-dev -f scripts/agent-benchmark/dev-image/Dockerfile /path/to/app/server
node scripts/agent-benchmark/run.mjs --agent reference --dev-image spree-bench-dev
```

The harness then points the project's `docker-compose.dev.yml` at that image
before the baseline commit, so the agent's diff does not show the change.

## Test the scorer

```bash
node --test 'scripts/agent-benchmark/test/*.test.mjs'
```

The fixtures in `test/fixtures/` are small hand-written transcripts, one per
transcript format.
