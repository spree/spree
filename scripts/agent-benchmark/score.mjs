#!/usr/bin/env node
// Scores a results directory written by run.mjs: parses every transcript into
// the benchmark metrics and writes report.json and report.md next to the runs.
//
//   node scripts/agent-benchmark/score.mjs <results dir>
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { isClean, scoreTranscript } from './lib/transcript.mjs'

const readJson = (file) => (fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null)

export function scoreRun(runDir) {
  const meta = readJson(path.join(runDir, 'meta.json'))
  if (!meta) return null
  const transcriptPath = path.join(runDir, 'transcript.jsonl')
  const transcript = fs.existsSync(transcriptPath) ? fs.readFileSync(transcriptPath, 'utf8') : ''
  const metrics = scoreTranscript(transcript, { format: meta.format })
  const acceptance = readJson(path.join(runDir, 'acceptance.json')) ?? {
    passed: false,
    details: 'No acceptance result.',
  }
  return {
    run: path.basename(runDir),
    task: meta.task,
    agent: meta.agent,
    model: meta.model,
    attempt: meta.attempt,
    passed: acceptance.passed === true,
    needsHumanReview: acceptance.needsHumanReview === true,
    clean: isClean(metrics, acceptance.passed) && !meta.harnessError,
    harnessError: meta.harnessError ?? null,
    agentTimedOut: meta.agentTimedOut ?? false,
    wallMs: meta.wallMs ?? null,
    acceptance,
    metrics,
  }
}

function median(values) {
  const sorted = values.filter((value) => typeof value === 'number').sort((a, b) => a - b)
  if (sorted.length === 0) return null
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
}

const sum = (values) => values.reduce((total, value) => total + (value ?? 0), 0)

export function summarize(runs) {
  const groups = new Map()
  for (const run of runs) {
    const key = `${run.task}\u0000${run.agent}`
    groups.set(key, [...(groups.get(key) ?? []), run])
  }
  return [...groups.values()].map((group) => {
    const pick = (name) => group.map((run) => run.metrics[name])
    return {
      task: group[0].task,
      agent: group[0].agent,
      runs: group.length,
      passed: group.filter((run) => run.passed).length,
      clean: group.filter((run) => run.clean).length,
      medianModelCalls: median(pick('modelCalls')),
      medianToolCalls: median(pick('toolCalls')),
      medianToolOutputChars: median(pick('toolOutputChars')),
      gemSourceReads: sum(pick('gemSourceReads')),
      packageSourceReads: sum(pick('packageSourceReads')),
      docsLookups: sum(pick('docsLookups')),
      removedApiUses: sum(pick('removedApiUses')),
      legacyCodeWritten: sum(pick('legacyCodeWritten')),
      deprecationFailures: sum(pick('deprecationFailures')),
      directCommands: sum(pick('directCommands')),
      medianDurationMs: median(pick('durationMs')),
      totalCostUsd: sum(pick('costUsd')),
    }
  })
}

// Removed APIs and stumbles across every run, most frequent first.
function tally(runs, select) {
  const counts = {}
  for (const run of runs) {
    for (const [name, n] of select(run)) counts[name] = (counts[name] ?? 0) + n
  }
  return Object.entries(counts).sort((a, b) => b[1] - a[1])
}

const fmt = (value, digits = 0) => (value == null ? '–' : Number(value).toFixed(digits))

export function renderMarkdown(report) {
  const lines = [
    '# Spree agent benchmark',
    '',
    `${report.runs.length} runs, scored ${report.generatedAt}.`,
    'A run is clean when its check passed and it hit no removed-API hint, deprecation failure or gem source read.',
    '',
    '| Task | Agent | Runs | Passed | Clean | Model calls | Tool calls | Tool output (KB) | Gem reads | Package reads | Docs lookups | Removed APIs | Legacy code | Deprecation failures | Direct commands | Time (min) | Cost ($) |',
    '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |',
  ]
  for (const row of report.summary) {
    lines.push(
      `| ${row.task} | ${row.agent} | ${row.runs} | ${row.passed} | ${row.clean} | ${fmt(row.medianModelCalls)} | ${fmt(row.medianToolCalls)} | ${fmt(row.medianToolOutputChars == null ? null : row.medianToolOutputChars / 1024, 1)} | ${row.gemSourceReads} | ${row.packageSourceReads} | ${row.docsLookups} | ${row.removedApiUses} | ${row.legacyCodeWritten} | ${row.deprecationFailures} | ${row.directCommands} | ${fmt(row.medianDurationMs == null ? null : row.medianDurationMs / 60_000, 1)} | ${fmt(row.totalCostUsd, 2)} |`,
    )
  }
  lines.push(
    '',
    'Model calls, tool calls, tool output and time are medians per run; the rest are totals.',
  )

  const removed = tally(report.runs, (run) => Object.entries(run.metrics.removedApis))
  if (removed.length > 0) {
    lines.push('', '## Removed APIs agents called', '')
    for (const [name, n] of removed) lines.push(`- \`${name}\` — ${n}`)
  }

  lines.push('', '## Runs')
  for (const run of report.runs) {
    const status = run.harnessError
      ? 'harness error'
      : run.clean
        ? 'clean'
        : run.passed
          ? 'passed with stumbles'
          : 'failed'
    lines.push('', `### ${run.run} — ${status}`, '')
    if (run.harnessError) lines.push('```', run.harnessError.slice(0, 1500), '```')
    if (run.agentTimedOut) lines.push('- The agent hit the task timeout.')
    if (run.needsHumanReview) lines.push('- Read the answer: this task is also scored by a human.')
    if (!run.passed && !run.harnessError) {
      const details =
        typeof run.acceptance.details === 'string'
          ? run.acceptance.details
          : JSON.stringify(run.acceptance.details, null, 2)
      lines.push(
        '<details><summary>Acceptance output</summary>',
        '',
        '```',
        details.slice(-3000),
        '```',
        '</details>',
        '',
      )
    }
    for (const stumble of run.metrics.stumbles.slice(0, 25)) {
      const label = stumble.api ? `${stumble.kind} (${stumble.api})` : stumble.kind
      lines.push(`- **${label}**: \`${stumble.excerpt.replace(/`/g, "'")}\``)
    }
    if (run.metrics.stumbles.length > 25)
      lines.push(`- …and ${run.metrics.stumbles.length - 25} more in report.json`)
  }
  return `${lines.join('\n')}\n`
}

export function buildReport(outDir) {
  const runs = fs
    .readdirSync(outDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => scoreRun(path.join(outDir, entry.name)))
    .filter(Boolean)
    .sort((a, b) => a.run.localeCompare(b.run))
  return { generatedAt: new Date().toISOString(), runs, summary: summarize(runs) }
}

export function writeReport(outDir) {
  const report = buildReport(outDir)
  const jsonPath = path.join(outDir, 'report.json')
  const markdownPath = path.join(outDir, 'report.md')
  fs.writeFileSync(jsonPath, JSON.stringify(report, null, 2))
  fs.writeFileSync(markdownPath, renderMarkdown(report))
  return { report, jsonPath, markdownPath }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const outDir = process.argv[2]
  if (!outDir || !fs.existsSync(outDir)) {
    console.error('Usage: node scripts/agent-benchmark/score.mjs <results dir>')
    process.exit(64)
  }
  const { markdownPath, jsonPath } = writeReport(path.resolve(outDir))
  console.log(`Wrote ${jsonPath}\nWrote ${markdownPath}`)
}
