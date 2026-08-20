# Phase 0 spike — dashboard assistant approval gate

Executable proof for `docs/plans/6.0-dashboard-assistant.md` phase 0: does
RubyLLM let a mutating tool pause the agent loop for human approval, and
resume correctly afterwards?

**Verdict: GO** — see `FINDINGS.md` for results, the mechanism, and the two
traps that bind phase 1.

```bash
bundle install
bundle exec ruby spike.rb
```

No API key is needed. The provider endpoint is stubbed, so the spike asserts
the control flow (halt, persistence, approve, reject, resume, permission
filtering) rather than model behaviour, and is deterministic in CI.

This is a throwaway harness kept as the record of why the design is what it
is. It is not loaded by any gem. When phase 1 lands, its assertions — above
all the one on the outbound provider payload after a resume — move into the
`spree/assistant` suite and this directory can go.
