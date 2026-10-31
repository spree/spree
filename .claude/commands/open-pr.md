---
description: Review, security-review, open and monitor a pull request for the current branch.
---

Take the current branch from finished work to an open, monitored pull request
on `spree/spree`. Run the steps in order and skip none because the change looks
small. A pre-tool hook blocks `gh pr create` until steps 1–3 have run on the
current `HEAD`.

Never run this on `main`: branch first (`feat/`, `fix/` or `chore/`). Commit any
uncommitted work before step 1 so the reviews see it.

## 1. Code review

Run `/code-review --fix` on the branch. Re-run `pnpm test:changed`, then commit
the fixes. A finding you reject gets a one-line reason for the final report,
not silence.

## 2. Security review

Run `/security-review` on the branch. Fix every confirmed finding, re-run
`pnpm test:changed`, and commit. Record rejected findings the same way. If a
fix changed code, go back to step 1 so the fix gets a code review too.

## 3. Record the reviewed commit

With the working tree clean:

```bash
git rev-parse HEAD > "$(git rev-parse --absolute-git-dir)/claude-reviewed"
```

Any later commit makes this stale; go back to step 1 before opening the PR.

## 4. Open the pull request

Push the branch, then open the PR with
`gh pr create --repo spree/spree --base main`. Follow AGENTS.md "Git" for the
title and body. When a Linear issue exists, end the title with its id in
parentheses and add `Linear: V-1234` on its own line in the body.

## 5. Monitor it

Run `/autofix-pr` to watch review comments and CI, fix what comes back, and
push each round as its own commit. Stop and report when something needs the
user: a required review, a failing check you cannot reproduce, a permission
error.

## Final report

The PR URL, the review findings fixed, the findings skipped with their reasons,
and the CI state when monitoring stopped.
