# Phase 0 spike — findings

**Verdict: GO.** RubyLLM supports the approval gate. All 21 checks pass in
`spike.rb` (runnable, no API key — the Anthropic endpoint is stubbed with
WebMock so the control flow is what's under test, not the model).

Run: `bundle exec ruby spike.rb`

## What was proven (ruby_llm 1.16.0)

| # | Claim | Result |
|---|---|---|
| 1 | Read tools auto-execute, turn completes | ✅ |
| 2 | Mutating tool halts the loop; nothing written; call persisted with arguments; placeholder tool-result persisted in the right slot | ✅ |
| 3 | Approve → executes → conversation resumes → model receives the REAL result | ✅ |
| 4 | Reject → nothing written → model told the user declined → conversation resumes | ✅ |
| 5 | Tool list filtered by permissions — a viewer never sees the mutating tool | ✅ |

## Mechanism in 1.16.0

`RubyLLM::Tool::Halt` + the protected `halt(message)` helper. Returning it
from `execute` makes `Chat#handle_tool_calls` skip its recursive `complete`
(`halt_result || complete(&)`), so `ask` returns the `Halt` object instead of
a `Message`.

The load-bearing property: `add_tool_result_message` unwraps the Halt and
persists it as a normal `role: :tool` message **before** the loop stops. The
history is therefore left valid and resumable — the tool call has a matching
result, so no provider rejects a dangling call. That placeholder row is the
slot the approval later overwrites with the real result.

Resume is `to_llm`, which does `reset_messages!` then replays the persisted
rows. So: update the tool-result row, rebuild, `complete`.

## Two traps found while building this (both cost a red run)

1. **The messages table needs a `tool_call_id` reference column**, not
   `parent_tool_call_id`. `persist_message_completion` assigns
   `message.tool_call_id`; naming the column after the association fails with
   `undefined method 'tool_call_id='`.
2. **Resuming needs `chat_record.reload`, not just dropping `@chat`.**
   `to_llm` replays `messages_association.to_a`, which is a cached
   association. Without the reload the model is re-sent the stale
   `AWAITING_APPROVAL` placeholder and cheerfully confirms work it never saw
   done — a silent, plausible-looking wrong answer. This is the single most
   dangerous failure mode in the whole flow and it is invisible without
   asserting on the actual outbound request body. **Phase 1 must keep an
   assertion on what the provider receives after a resume.**

## The 2.0 finding — changes the wrapper, not the verdict

RubyLLM 2.0 (merged on `main`, unreleased) **removes `Tool::Halt`** and
replaces it with a first-class `requires_approval`. Verified in
`ruby_llm-main/lib/ruby_llm/tool.rb` and `chat.rb`; the upgrade generator
lists `halt, Tool::Halt -> loop verbs or requires_approval`.

The 2.0 shape is strictly closer to what this plan wants — its own docs use
`IssueRefund`/`requires_approval` as the example:

- `requires_approval` (optionally with a resolver block) on the tool class
- the loop **parks** the call; `complete` returns cleanly with
  `awaiting_approval?` true and `pending_approvals`
- `Chat#approve!(tool_call)` / `Chat#deny!(tool_call)`
- in Rails the decision persists on the tool-call record and **survives
  process restarts** — better than the hand-rolled 1.x resume

Consequences for phase 1:

- Pin `~> 1.16.0`.
- **Never let `RubyLLM::Tool::Halt` leak past the adapter.** The polymorphic
  return of `ask` (Halt vs Message) plus the 2.0 removal means every leaked
  call site is a future edit. `Spree::Assistant::RunTurn` returns a Spree
  value object; the registry stays library-agnostic. This is what the
  Spree-owned-registry decision already required — the spike confirms the
  cost of not doing it.
- Migrating to 2.0 should then be a change to one adapter file, and it lets
  us delete the hand-rolled reload/resume dance (trap 2 above) entirely.
