Update an existing plan document.

Instructions: $ARGUMENTS

1. List all plans in `docs/plans/` (excluding `_template.md`)
2. Identify the relevant plan based on the instructions
3. Read the current plan content
4. Apply the requested changes while preserving the document structure
5. **Resolve open questions interactively before finishing** — see below
6. Update the `Last updated` date
7. If status changed, update the reference in root `CLAUDE.md`

## Resolving open questions (required)

Never leave a plan sitting on unresolved open questions after an edit. Before
finishing, check the plan's **Open Questions** section and use the
`AskUserQuestion` tool to settle anything the author can decide now — both
questions that were already there and any your changes introduced.

- Ask them **together in one call** where possible (the tool takes up to 4
  questions), so the author sees the whole decision surface at once.
- For each question give **2–4 concrete options**, not an open prompt. Lead with
  your recommendation and mark it `(Recommended)`.
- Use the `preview` field to show the actual shape of each option — the code,
  the config, or the schema it implies.
- State the **cost** of each option in its description, not just what it does.

Then fold the answers back into the plan:

- Move each resolved question out of **Open Questions** into **Key Decisions**,
  phrased as a decision with its date and the reasoning that settled it.
- Record any **accepted trade-off** explicitly, and if it constrains how other
  code must be written, add it to **Constraints on Current Work**.
- Leave **Open Questions** holding only genuinely deferred items, each with a
  note on what would unblock it.
- If the last blocking question is now settled, move the status off `Draft`.

If a question genuinely cannot be answered yet — it depends on work that hasn't
landed, or on information nobody has — say so and leave it deferred with the
reason. That is a resolution too; silently leaving it unexamined is not.

## Recording decisions

When an update settles something significant — a reversal, a cross-plan
constraint, or a decision other plans will need to reference — also add a dated
entry to `docs/plans/decisions.md`, and add a superseding note to any other plan
whose Key Decisions this contradicts. A decision that lives in only one plan
will be missed by whoever reads the other one.
