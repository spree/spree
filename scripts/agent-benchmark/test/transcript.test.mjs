import assert from 'node:assert/strict'
import fs from 'node:fs'
import { describe, it } from 'node:test'
import { isClean, parseJsonl, scoreTranscript } from '../lib/transcript.mjs'

const fixture = (name) => fs.readFileSync(new URL(`fixtures/${name}`, import.meta.url), 'utf8')

describe('Claude stream-json transcripts', () => {
  const text = fixture('claude-stream.jsonl')
  const metrics = scoreTranscript(text)

  it('counts each model response once, even when it streams as several events', () => {
    assert.equal(metrics.modelCalls, 9)
  })

  it('counts tool calls by name', () => {
    assert.equal(metrics.toolCalls, 8)
    assert.deepEqual(metrics.toolCallsByName, { Read: 2, Bash: 5, Write: 1 })
  })

  it('measures tool output volume and errors', () => {
    const expected = parseJsonl(text)
      .filter((event) => event.type === 'user')
      .flatMap((event) => event.message.content)
      .map((block) => (typeof block.content === 'string' ? block.content : block.content[0].text))
      .reduce((total, content) => total + content.length, 0)
    assert.equal(metrics.toolOutputChars, expected)
    assert.equal(metrics.toolErrors, 3)
  })

  it('separates gem source reads, package source reads and docs lookups', () => {
    assert.equal(metrics.gemSourceReads, 1)
    assert.equal(metrics.packageSourceReads, 1)
    assert.equal(metrics.docsLookups, 1)
  })

  it('reads removed-API hints from tool output', () => {
    assert.deepEqual(metrics.removedApis, { 'Spree::Order#adjustments': 1 })
    assert.equal(metrics.removedApiUses, 1)
  })

  it('flags legacy Spree code the agent wrote', () => {
    assert.equal(metrics.legacyCodeWritten, 2)
    const apis = metrics.stumbles.filter((s) => s.kind === 'legacy_code_written').map((s) => s.api)
    assert.deepEqual(apis.sort(), ['.adjustments', 'order.completed event'])
  })

  it('counts deprecation failures and warnings', () => {
    assert.equal(metrics.deprecationFailures, 1)
    assert.equal(metrics.deprecationWarnings, 2)
  })

  it('counts commands AGENTS.md says to run through the CLI', () => {
    assert.equal(metrics.directCommands, 1)
  })

  it('takes time, turns and cost from the result event', () => {
    assert.equal(metrics.durationMs, 185000)
    assert.equal(metrics.numTurns, 9)
    assert.equal(metrics.costUsd, 1.2345)
    assert.equal(metrics.agentError, false)
  })

  it('is not clean when the run stumbled, even though the check passed', () => {
    assert.equal(isClean(metrics, true), false)
  })

  it('lists every stumble with an excerpt', () => {
    const kinds = metrics.stumbles.map((s) => s.kind)
    for (const kind of [
      'gem_source_read',
      'legacy_code_written',
      'removed_api',
      'deprecation_failure',
      'direct_command',
    ]) {
      assert.ok(kinds.includes(kind), `missing ${kind}`)
    }
    assert.ok(metrics.stumbles.every((s) => s.excerpt.length > 0))
  })
})

describe('clean runs', () => {
  const lines = [
    {
      type: 'assistant',
      message: {
        id: 'm1',
        content: [
          { type: 'tool_use', id: 't1', name: 'Bash', input: { command: 'npx spree test' } },
        ],
      },
    },
    {
      type: 'user',
      message: {
        content: [{ type: 'tool_result', tool_use_id: 't1', content: '3 examples, 0 failures' }],
      },
    },
    { type: 'result', subtype: 'success', is_error: false, duration_ms: 1000, total_cost_usd: 0.1 },
  ]
  const metrics = scoreTranscript(lines.map((line) => JSON.stringify(line)).join('\n'))

  it('is clean when the check passed and nothing stumbled', () => {
    assert.equal(isClean(metrics, true), true)
  })

  it('is not clean when the check failed', () => {
    assert.equal(isClean(metrics, false), false)
  })

  it('treats a transcript without a result event as an agent error', () => {
    const cut = scoreTranscript(
      lines
        .slice(0, 2)
        .map((line) => JSON.stringify(line))
        .join('\n'),
    )
    assert.equal(cut.agentError, true)
    assert.equal(isClean(cut, true), false)
  })
})

describe('direct commands', () => {
  const directCommands = (command) => {
    const event = {
      type: 'assistant',
      message: {
        id: 'm1',
        content: [{ type: 'tool_use', id: 't1', name: 'Bash', input: { command } }],
      },
    }
    return scoreTranscript(JSON.stringify(event)).directCommands
  }

  it('counts Rails, Bundler, RSpec and Compose run directly', () => {
    assert.equal(directCommands('cd server && bin/rails db:migrate'), 1)
    assert.equal(directCommands('docker compose exec web bin/rails c'), 1)
    assert.equal(directCommands('rspec spec/models'), 1)
  })

  it('does not count the same commands run through the Spree CLI', () => {
    assert.equal(directCommands('npx spree exec bin/rails runner "p 1"'), 0)
    assert.equal(directCommands('npx spree bundle exec rake -T'), 0)
    assert.equal(directCommands('npx spree rspec spec/models'), 0)
  })
})

describe('Codex transcripts', () => {
  const metrics = scoreTranscript(fixture('codex.jsonl'), { format: 'codex' })

  it('reads commands, gem reads and removed-API hints', () => {
    assert.equal(metrics.modelCalls, 1)
    assert.equal(metrics.toolCalls, 2)
    assert.equal(metrics.gemSourceReads, 1)
    assert.deepEqual(metrics.removedApis, { 'Spree::Variant#price=': 1 })
    assert.equal(metrics.toolErrors, 1)
  })
})
