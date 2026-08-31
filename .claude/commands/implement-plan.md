---
description: Deliver a docs/plans plan end to end — settle open questions, implement with local CI, two code reviews plus a simplify pass, running QA environment with seeded data, schema review, and an open, monitored pull request on spree/spree.
argument-hint: <plan filename or slug>
---

Implement a plan from `docs/plans/` end to end — from reading it to an open,
monitored pull request on `spree/spree` with a running environment for manual QA.

Plan: $ARGUMENTS (a plan filename or slug; if empty, list the plans in
`docs/plans/` whose status shows unbuilt work and ask which one)

## How this run works

The goal is to **deliver the plan autonomously and hand the user a finished
result**: a working development server with seeded data, a reviewed and tested
branch, an open pull request, and QA instructions — all in one run, without the
user steering it.

- Stage 2 (open questions) is the **only** point where you stop to ask. After
  the answers are recorded, run every remaining stage without checking in.
  Routine judgment calls (a column name, a spec's shape, which sample records
  to seed) are yours to make; note them for the final report instead of asking.
- Stop early only for a destructive action the plan does not call for, or a
  blocker only the user can clear (missing credentials, a permission error, a
  CI failure you cannot reproduce locally). Say what blocked you and what you
  finished before it.
- Do every stage in order and do not skip one because it looks unnecessary.
  Each stage has a clear "done" condition; move on only when it is met.
- Work happens in a git worktree (`wt switch -c <branch>`), never on `main`,
  on a `feature/`, `fix/` or `chore/` branch named after the plan.
- Keep servers running at the end. The user opens the URLs from the report;
  shutting the environment down is their call, not yours.

## 1. Read the plan carefully

- Read the plan file in full. Then read every plan it links to or names, the
  matching entry in the "Architecture Plans" section of the root `CLAUDE.md`,
  and the dated entries in `docs/plans/decisions.md` that touch it.
- Work out exactly what is still unbuilt: which phases are marked implemented,
  which are pending, what "6.0 scope" versus "6.1 scope" means for this run.
  Confirm claims of "shipped" against the code — grep for the classes and
  migrations the plan says exist.
- Collect every constraint that applies: the plan's own **Constraints on Current
  Work**, plus the constraints of *other* plans that mention the same models,
  tables or endpoints (a plan is bound by its neighbours' rulings too).
- Write down, in your own words, the list of deliverables before touching code.
  If the plan has phases, say which ones this run covers. The default is
  everything the plan targets for the current release.

## 2. Settle open questions interactively

If the plan's **Open Questions** section is not empty, or the reading raised a
decision the plan does not make, resolve them **before** implementation with
the `AskUserQuestion` tool:

- Ask them together in one call where possible (up to 4 per call), each with
  2–4 concrete options, your recommendation first and marked `(Recommended)`,
  and the cost of each option in its description. Use `preview` to show the
  code, schema or config shape an option implies.
- Record the answers the way `/project:update-plan` does: move each resolved
  question into **Key Decisions** with today's date and the reasoning, add
  accepted trade-offs to **Constraints on Current Work** if they bind other
  code, add a dated entry to `docs/plans/decisions.md` for anything other plans
  will need to reference, and update `Last updated`.

Do not pick answers silently and do not defer a question you could ask now. A
question that genuinely cannot be answered yet stays in Open Questions with the
reason.

## 3. Implement

- Start with `/goal` so the run has a stated goal to check itself against:
  the deliverables from stage 1 plus green local CI.
- Follow the plan's phase order and every convention in `CLAUDE.md` (models,
  migrations, API controllers, serializers, dashboard, translations in every
  locale, type generation pipeline when serializers change, OpenAPI regenerated
  from the integration specs — never edited by hand).
- Test in two passes, always locally, always before moving on:
  1. **Affected code first.** Run the specs for the files you changed (`bundle
     exec rspec <paths>` in the engine, `pnpm test` / `pnpm exec tsc -b` in the
     package). Iterate here until green — this is the fast loop.
  2. **Then the full suite, the way CI runs it.** For every engine you touched
     (`spree/core`, `spree/api`, `spree/emails`, `spree/providers/*`,
     `spree/dashboard`, `spree/opentelemetry`): `bundle exec rake test_app`
     if the dummy app is stale, `bundle exec rake parallel_setup` after any
     schema change, then `bundle exec parallel_rspec spec`. Re-run any failing
     example on its own before investigating — confirm it really fails. For the
     TypeScript packages: `pnpm turbo lint typecheck test build --force` from
     the repo root (the `--force` matters — a cached run reads the SDK's stale
     `dist`). If the dashboard changed, run the affected Playwright specs with
     `pnpm wt:e2e <spec>`.
- Commit as you go in logical units. The commit body says what and why, never
  how; use `git commit --fixup` for follow-ups to a change and squash them
  before opening the PR. No `Co-Authored-By` or "generated with" trailers.

Done when: every deliverable from stage 1 exists, and both test passes are
green.

## 4. Code review — first round

Run `/code-review` on the branch. Fix every confirmed finding, re-run the
affected specs, commit. A finding you disagree with gets a one-line reason in
your notes for the final report, not silence.

## 5. Simplify

Run `/simplify` on the changed code. Apply the cleanups it proposes that keep
behaviour identical; re-run the affected specs after, then the full suite for
any engine or package the simplification touched.

## 6. Code review — second round

Run `/code-review` again on the result. Fix what it finds. Done when a review
round comes back clean or with findings you have explicitly decided not to act
on (and can justify).

## 7. Set up the application for manual QA

Bring up this worktree's environment so the user can try the feature by hand:

- If the change added migrations: `cd server && bin/rails
  spree:install:migrations db:migrate`, then `pnpm wt:template` so future
  worktrees inherit the schema.
- Seed whatever the feature needs to be visible. Sample products and images:
  `cd server && bin/rails spree:load_sample_data`. Sellers: `bin/rails
  spree:sellers:sample_data`. Anything feature-specific (a company, a catalog,
  a price list, a delivery method) — create it through the Admin API or a
  `bin/rails runner` script so the QA path starts from real records, and note
  what you created.
- Start Rails (`pnpm wt:dev`) and the dashboard (`pnpm wt:dashboard`) as
  background commands. Start the storefront (`pnpm wt:storefront`) or the
  seller panel (`pnpm wt:seller`) too when the plan touches them.
- Verify each server answers before reporting it: `curl -sk <rails url>/up`
  and a `200` from the dashboard URL. A URL you did not check is not ready.

## 8. Schema review

Run `/schema-review` for the branch. It publishes the ERD and lifecycle
artifact for the reviewer; keep the URL for the report. If the change touched
no migrations the review will say so — run it anyway, "no schema change" is a
useful thing for a reviewer to have verified.

## 9. Report for manual QA

Print, in one block the user can act on directly:

- **URLs** — Rails API, dashboard, and storefront / seller panel if started
  (`scripts/worktree/lib.sh` has `rails_url`, `dashboard_url`,
  `storefront_url`, `seller_url`; the dev scripts print them at boot). Also
  Mailpit (<http://localhost:8025>) when the feature sends email.
- **Credentials** — admin `spree@example.com` / `spree123` unless the seed was
  run with other values; any seller, customer or company account you created
  for the QA path, with its password.
- **QA instructions** — a numbered walkthrough per deliverable: where to click,
  what to enter, what the expected result is, and what would count as a
  failure. Include the negative cases the plan cares about (a cross-store id
  must 404, an invalid quantity must be refused with a message, and so on).
  Skip this only when the change has no user-facing surface, and say so.
- The schema-review artifact URL.

## 10. Open the pull request and monitor it

- Squash fixups, make sure the branch is pushed to `spree/spree`, then open the
  PR with `gh pr create --repo spree/spree --base main`. The body: what the
  change does and why, which plan it implements and which phases, the
  decisions settled in stage 2, how it was tested, and the QA walkthrough from
  stage 9. Link the plan file. Keep implementation detail out of it.
- Run `/autofix-pr` to watch review comments (humans, Bugbot, CodeRabbit) and
  CI, fix what comes back, and push. Stop and report clearly if something
  needs the user — a required review, a failing check you cannot reproduce
  locally, a permission error.

## Final report

End with a summary that stands on its own: the PR URL, what was built (by
deliverable), the decisions recorded, the review findings acted on and the
ones deliberately skipped, the QA block from stage 9, and anything left for a
follow-up with the reason.
