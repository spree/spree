Review a change's database impact and publish it as a visual artifact.

Target: $ARGUMENTS (a PR number, a branch, a commit range, or empty for the current branch against `main`)

The output is a published Artifact the reviewer can open — an ERD showing what
this change adds to the database, plus the lifecycle and permission surface
around it. It exists so a reviewer can see the shape of a schema change before
reading the diff.

## 1. Establish the range

- A bare number is a PR: `gh pr view <n> --json headRefName,baseRefName`.
- A branch or range is used as given.
- Empty means `origin/main...HEAD`.

Fetch first so the base is current.

## 2. Gather facts — never from memory

Every figure on the page must come from a command you ran in this session. The
whole value of the artifact is that it is trustworthy at a glance, so a number
you assumed is worse than a number you left out.

```bash
# New tables
git diff <range> --name-only --diff-filter=A | grep db/migrate

# Changed tables — only migrations that ALTER what already exists.
# Excludes the create_* files found above, whose add_index lines would
# otherwise read as a change to an existing table.
git diff <range> -- '*/db/migrate/*' ':!*create_*' \
  | grep -E "^\+.*(add_column|add_reference|remove_column|rename_column)"

# New models, workflows, services, serializers
git diff <range> --name-only --diff-filter=A | grep -E "app/(models|workflows|services|serializers)/"
```

Then read each new migration in full for the exact columns, types, null
constraints and indexes. Read each new model for `has_status`, `has_prefix_id`,
`belongs_to`, and any `dependent:`.

**State "no change" explicitly when that is the answer.** "No existing table
gained a column" is one of the most useful things the page can say, and it only
carries weight if you checked.

Verify anything you are unsure of against the running app rather than guessing:

```bash
cd server && bin/rails runner 'puts Spree::Thing.column_names.inspect'
```

Watch for claims that read as true but are not: a model whose comments mention
another entity does not reference it. Grep for the association, not the word.

## 3. Decide what belongs on the page

Include, in this order, and only the ones that apply:

- **Counts** — new tables, columns, foreign keys, and explicitly `0` where
  nothing changed.
- **ERD** — the new table(s) drawn solid; the existing tables they reference
  drawn as outlines. That contrast is what makes "what's new" readable before
  any words are.
- **Lifecycle** — if the new table has a `status`, one row per value: the
  status, the workflow that writes it, and what it means. Never a state-machine
  graph; Spree has no state machines.
- **Vocabulary changes** — statuses added to an existing model via
  `add_status`, which are a code change rather than a migration and so are
  invisible in the schema.
- **Permission catalog** — resources registered or split, and who can reach
  them.
- **Derived columns** — anything deliberately *not* stored (a store derived
  through a parent, say) is worth showing as such; its absence is a design
  decision a reviewer should see.

Leave out anything you could not verify.

## 4. Build and publish

Load the `artifact-design` skill before writing the file, and follow it.

Design notes specific to this kind of page:

- It is a technical document read by engineers, not a marketing page. Utilitarian
  treatment, real typographic hierarchy, no hero.
- Column names, types and event names are the content — set them in a monospace
  face, and let that carry the character.
- Spend colour on one thing: the new table and its foreign keys. Everything
  existing stays neutral. Semantic colour is for statuses only.
- Use `font-variant-numeric: tabular-nums` wherever counts line up.
- Both themes, per the skill. Wide tables get their own `overflow-x: auto`.

Write the file to the scratchpad directory, then publish with `Artifact`. Title
it for the subject — the feature the schema serves, not "Schema Changes".

## 5. Report

Give the user the URL, then the same facts in prose: what was added, what was
deliberately not added, and anything you could not verify and left off.
