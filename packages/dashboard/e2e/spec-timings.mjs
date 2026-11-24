#!/usr/bin/env node
// Prints the seconds each spec file took, from a Playwright JSON report. CI
// prints this after every E2E shard, so the four lists of one run show where
// the suite's time goes.
//
// Usage: node e2e/spec-timings.mjs <report.json>
import fs from 'node:fs'

// A run that stopped before its tests leaves no report; say so, don't fail.
if (!fs.existsSync(process.argv[2])) {
  console.log(`No report at ${process.argv[2]}`)
  process.exit(0)
}

const report = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
const seconds = new Map()

// A retried test counts once, by its last attempt.
const visit = (suite, file) => {
  for (const spec of suite.specs ?? []) {
    for (const test of spec.tests) {
      const duration = test.results.at(-1)?.duration ?? 0
      seconds.set(file, (seconds.get(file) ?? 0) + duration / 1000)
    }
  }
  for (const child of suite.suites ?? []) visit(child, file)
}
for (const suite of report.suites) visit(suite, suite.file)

for (const [file, total] of [...seconds].sort()) {
  console.log(`${String(Math.round(total)).padStart(5)}  ${file}`)
}
