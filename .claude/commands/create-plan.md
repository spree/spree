Create a new architecture/feature plan document.

Plan topic: $ARGUMENTS

Follow this process:
1. Read the plan template at `docs/plans/_template.md`
2. Create a new plan file in `docs/plans/` with a kebab-case filename
3. Fill in all sections based on our discussion and any existing context
4. **Resolve every open question interactively before finishing** — see below
5. If the plan affects specific areas of the codebase, add cross-references in relevant directory-level CLAUDE.md files

The filename should follow the pattern: `{release}-{feature-slug}.md` 
(e.g., `6.0-cart-order-split.md`, `future-mcp-server.md`)

## Resolving open questions (required)

A draft plan that ships with unresolved open questions is not finished. After
writing the draft, **always** walk the author through every open question using
the `AskUserQuestion` tool — do not leave them for later, and do not pick
answers silently.

- Ask them **together in one call** where possible (the tool takes up to 4
  questions), so the author sees the whole decision surface at once.
- For each question give **2–4 concrete options**, not an open prompt. Lead with
  your recommendation and mark it `(Recommended)`.
- Use the `preview` field to show the actual shape of each option — the code,
  the config, or the schema it implies. Seeing `store.preference || global ||
  DEFAULT` next to `store.preference` makes the trade-off obvious in a way prose
  does not.
- State the **cost** of each option in its description, not just what it does.
  "More invasive, touches every caller" is the part the author is deciding on.

Then fold the answers back into the plan:

- Move each resolved question out of **Open Questions** into **Key Decisions**,
  phrased as a decision with its date and the reasoning that settled it.
- Record any **accepted trade-off** explicitly. If an option was chosen knowing
  it has a sharp edge, the plan must say so — and if that edge constrains how
  other code must be written, add it to **Constraints on Current Work**.
- Leave **Open Questions** holding only genuinely deferred items, each with a
  note on what would unblock it. If nothing is left, say so plainly rather than
  deleting the section.
- Once the questions are settled, the plan's status is no longer `Draft` —
  update it (typically to `Design finalized`).

Only skip the interactive pass if the draft genuinely raised no open questions —
which is rare, and worth double-checking before concluding.

## Recording decisions

When a new plan settles something significant — a decision other plans will need
to reference, or a constraint on how code elsewhere must be written — also add a
dated entry to `docs/plans/decisions.md`, and add a superseding note to any
existing plan whose Key Decisions it contradicts. A decision that lives in only
one plan will be missed by whoever reads the other one.
