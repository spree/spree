Create a new architecture/feature plan document.

Plan topic: $ARGUMENTS

Follow this process:
1. Read the plan template at `docs/plans/_template.md`
2. Create a new plan file in `docs/plans/` with a kebab-case filename
3. Fill in all sections based on our discussion and any existing context
4. **Resolve every open question interactively before finishing** — see below
5. **Open the tracking issues in Linear and GitHub** and record them in the
   plan's `Tracking` header line — see below
6. If the plan affects specific areas of the codebase, add cross-references in relevant directory-level CLAUDE.md files

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

## Tracking the plan in Linear and GitHub (required)

Every plan is tracked as one Linear issue and one GitHub issue, opened once
the open questions are settled so the issue describes the finished design.
Record both in the plan's `**Tracking:**` header line, as
`Linear V-NNNN · GitHub spree/spree#NNNN`. This section is the single
description of how the trackers are shaped; `/project:update-plan` and
`/project:implement-plan` refer back to it.

**Milestones follow the plan's Target.** A target of `Spree X.Y` maps to the
Linear milestone `X.Y` and the GitHub milestone `vX.Y`. If a milestone does
not exist yet, create it rather than leaving the issue unassigned. A plan
spanning two releases (`6.0-6.1-…`) goes on the earlier milestone.

### Linear

Use the Linear MCP tools (`save_issue`, `save_milestone`, `get_project`).
Load them with `ToolSearch` first. If no Linear tools are available in this
session, skip this half, write `Linear —` in the header, and say so in the
final message so the author can open it by hand.

- Team `Vendo`, project `Spree` (slug `spree-941226e25ecf`), milestone as
  above.
- Title is the plan's H1 exactly, with no release prefix — the milestone
  already says which release it is.
- Description, in plain words: the plan's Summary paragraph, its status line,
  what it depends on, the Migration Path steps, and a link to the plan file
  at `https://github.com/spree/spree/blob/main/docs/plans/<file>`. Add the
  same link through `links` so it shows as an attachment.
- Status follows the plan's status: `Draft` and `Design finalized` → Backlog,
  `In Progress` → In Progress, `Implemented` → Done, `Superseded` → Canceled.
- Leave priority, assignee and labels unset unless the author asks.

### GitHub

- `gh issue create --repo spree/spree --title "<H1>" --milestone "vX.Y"`.
  No `Feature Request` label: the Roadmap membership already says what it
  is. Add `💼 B2B` or `🤝 Multi Vendor` when the plan belongs to that
  track. The body is the same summary as the Linear issue,
  the link to the plan file, and a line `Tracked in Linear as V-NNNN`.
  The description is public: no customer names, no credentials, no local
  URLs.
- Add the issue to the Roadmap project (organisation project number 2) and
  set its Status to `Todo`. The `gh project` subcommands fail here with
  "unknown owner type", so go through GraphQL with `gh api graphql`:
  `addProjectV2ItemById` with the project id `PVT_kwDN3X7OACniig` and the
  issue's `node_id` (from `gh api repos/spree/spree/issues/<n>`), then
  `updateProjectV2ItemFieldValue` on the returned item with the Status
  field `PVTSSF_lADN3X7OACniis4BoTjq` and option `f75ad846` (Todo; In
  Progress is `47fc9ee4`, Done is `98236657`). This needs a token with the
  `project` scope; if the call fails with a scope error, keep going, write
  the GitHub issue number in the header anyway, and tell the author to add
  `project` to the token that `GITHUB_TOKEN` in their shell profile points
  at, then re-add the item.
- Once both exist, attach the GitHub issue URL to the Linear issue through
  `save_issue` `links`, so each tracker points at the other.

## Recording decisions

When a new plan settles something significant — a decision other plans will need
to reference, or a constraint on how code elsewhere must be written — also add a
dated entry to `docs/plans/decisions.md`, and add a superseding note to any
existing plan whose Key Decisions it contradicts. A decision that lives in only
one plan will be missed by whoever reads the other one.
