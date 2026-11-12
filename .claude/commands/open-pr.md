---
description: Review, security-review, autofix, open and monitor a pull request for the current branch.
---

Take the current branch from finished work to an open, monitored pull request
on `spree/spree`, in one uninterrupted run. Run the steps in order and skip
none because the change looks small. A pre-tool hook blocks `gh pr create`
until steps 1–3 have run on the branch's `HEAD` and that commit is pushed.

Never run this on `main`: branch first (`feat/`, `fix/` or `chore/`). Commit any
uncommitted work before step 1 so the reviews see it.

## Run it end to end

- `/code-review` and `/security-review` are sub-steps, not the end of this
  command. Each one ends with its own report (`/code-review` through
  `ReportFindings`). That report is input for the next step. Do not end the
  turn, summarize or wait for the user after it. Go straight on to the next
  step.
- Fix every finding yourself. Do not ask which ones to fix and do not ask
  before you commit, push or open the pull request.
- Reject a finding only when it is wrong: a false positive, already handled,
  or outside this branch's diff. Note a one-line reason for the final report.
- Stop early only for something you cannot fix: a test failure you cannot
  resolve, a fix that needs a product decision, or a permission error. Report
  it, and leave the pull request unopened.

## 1. Code review

Run `/code-review --fix` on the branch. Apply any finding the `--fix` pass left
unapplied. Re-run `pnpm test:changed`, fix what fails, then commit with a
`Fix: ` message.

## 2. Security review

Run `/security-review` on the branch. It only reports, so fix every confirmed
finding yourself. Re-run `pnpm test:changed`, fix what fails, then commit.

If step 2 changed code, run `/code-review --fix` once more on those fixes only,
and apply any finding it leaves unapplied. Re-run `pnpm test:changed`, fix what
fails, then commit. Then go to step 3. Do not loop further: two rounds are
enough.

## 3. Record the reviewed commit

With the working tree clean:

```bash
git rev-parse HEAD > "$(git rev-parse --absolute-git-dir)/claude-reviewed"
```

Any later commit makes this stale; go back to step 1 before opening the PR.

## 4. Open the pull request

Push the branch in one command, then open the PR in another with
`gh pr create --repo spree/spree --base main --head <branch>`. `--head` tells
the hook which worktree's review to check, so this works even when the session
started in another checkout. Keep `--head` before a multi-line `--body`, or
pass the body with `--body-file`. Follow AGENTS.md "Git" for the title and
body. When a Linear issue exists, end the title with its id in
parentheses and add `Linear: V-1234` on its own line in the body.

## 5. Monitor it

Run `/autofix-pr` to watch review comments and CI, fix what comes back, and
push each round as its own commit. Stop and report when something needs the
user: a required review, a failing check you cannot reproduce, a permission
error.

## Final report

The PR URL, the review findings fixed, the findings skipped with their reasons,
and the CI state when monitoring stopped.
