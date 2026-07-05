Create a new architecture/feature plan document.

Plan topic: $ARGUMENTS

Follow this process:
1. Read the plan template at `docs/plans/_template.md`
2. Create a new plan file in `docs/plans/` with a kebab-case filename
3. Fill in all sections based on our discussion and any existing context
4. Update the "Architecture Plans" section in the root `CLAUDE.md` to include the new plan
5. If the plan affects specific areas of the codebase, add cross-references in relevant directory-level CLAUDE.md files

The filename should follow the pattern: `{release}-{feature-slug}.md` 
(e.g., `6.0-cart-order-split.md`, `future-mcp-server.md`)
