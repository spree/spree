import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { after, describe, it } from 'node:test'
import { writeReport } from '../score.mjs'

const fixture = new URL('fixtures/claude-stream.jsonl', import.meta.url)

function writeRun(outDir, name, { meta, acceptance, transcript }) {
  const dir = path.join(outDir, name)
  fs.mkdirSync(dir)
  fs.writeFileSync(path.join(dir, 'meta.json'), JSON.stringify({ format: 'stream-json', ...meta }))
  if (acceptance) fs.writeFileSync(path.join(dir, 'acceptance.json'), JSON.stringify(acceptance))
  if (transcript) fs.writeFileSync(path.join(dir, 'transcript.jsonl'), transcript)
}

describe('writeReport', () => {
  const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-benchmark-test-'))
  after(() => fs.rmSync(outDir, { recursive: true, force: true }))

  const clean = [
    { type: 'assistant', message: { id: 'm1', content: [{ type: 'text', text: 'ok' }] } },
    {
      type: 'result',
      subtype: 'success',
      is_error: false,
      duration_ms: 60000,
      total_cost_usd: 0.5,
    },
  ]
    .map((event) => JSON.stringify(event))
    .join('\n')

  writeRun(outDir, 'order-sync-subscriber--claude--1', {
    meta: { task: 'order-sync-subscriber', agent: 'claude', attempt: 1, wallMs: 1 },
    acceptance: { passed: true, details: 'ok' },
    transcript: fs.readFileSync(fixture, 'utf8'),
  })
  writeRun(outDir, 'order-sync-subscriber--claude--2', {
    meta: { task: 'order-sync-subscriber', agent: 'claude', attempt: 2, wallMs: 1 },
    acceptance: { passed: true, details: 'ok' },
    transcript: clean,
  })
  writeRun(outDir, 'order-sync-subscriber--claude--3', {
    meta: {
      task: 'order-sync-subscriber',
      agent: 'claude',
      attempt: 3,
      harnessError: 'Error: spree init failed',
    },
  })
  fs.writeFileSync(path.join(outDir, 'not-a-run.txt'), '')

  const { report, jsonPath, markdownPath } = writeReport(outDir)

  it('scores every run directory', () => {
    assert.equal(report.runs.length, 3)
    assert.deepEqual(
      report.runs.map((run) => [run.attempt, run.passed, run.clean]),
      [
        [1, true, false],
        [2, true, true],
        [3, false, false],
      ],
    )
  })

  it('summarizes runs per task and agent', () => {
    assert.equal(report.summary.length, 1)
    const [row] = report.summary
    assert.equal(row.runs, 3)
    assert.equal(row.passed, 2)
    assert.equal(row.clean, 1)
    assert.equal(row.gemSourceReads, 1)
    assert.equal(row.removedApiUses, 1)
    assert.equal(row.totalCostUsd, 1.7345)
  })

  it('writes the JSON and Markdown reports', () => {
    assert.deepEqual(JSON.parse(fs.readFileSync(jsonPath, 'utf8')).summary, report.summary)
    const markdown = fs.readFileSync(markdownPath, 'utf8')
    assert.match(markdown, /\| order-sync-subscriber \| claude \| 3 \| 2 \| 1 \|/)
    assert.match(markdown, /`Spree::Order#adjustments` — 1/)
    assert.match(markdown, /order-sync-subscriber--claude--1 — passed with stumbles/)
    assert.match(markdown, /order-sync-subscriber--claude--3 — harness error/)
    assert.match(markdown, /\*\*gem_source_read\*\*/)
  })
})
