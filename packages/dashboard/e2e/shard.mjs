#!/usr/bin/env node
// Prints the spec files of one CI shard, one per line, as file arguments for
// `playwright test`. Playwright reads each argument as a regular expression,
// so every line is escaped and anchored to match its own file and no other.
//
// Playwright's own `--shard` gives every shard the same number of tests, but
// the product specs take much longer per test, so one shard ran up to twice
// as long as another. File size tracks duration far more closely, and it is
// the weight the Ruby suites shard by too (`parallel_shard` in spree/core).
// Every runner sees the same files and sizes, so the shards never overlap and
// never miss a spec.
//
// Usage: node e2e/shard.mjs <shard> <total>
import fs from 'node:fs'
import path from 'node:path'

const [shard, total] = process.argv.slice(2).map(Number)
if (!(Number.isInteger(total) && Number.isInteger(shard) && shard >= 1 && shard <= total)) {
  console.error('Usage: node e2e/shard.mjs <shard> <total>, with 1 <= shard <= total')
  process.exit(1)
}

// The same files playwright.config.ts runs: every spec but `first-run/`.
const dir = import.meta.dirname
const specs = fs
  .readdirSync(dir, { recursive: true })
  .map((file) => file.split(path.sep).join('/'))
  .filter((file) => /\.(spec|test)\.[cm]?[jt]sx?$/.test(file) && !file.startsWith('first-run/'))
  .map((file) => ({ file, size: fs.statSync(path.join(dir, file)).size }))
  .sort((a, b) => b.size - a.size || (a.file < b.file ? -1 : 1))

// Largest first, each into the lightest shard so far.
const shards = Array.from({ length: total }, () => ({ size: 0, files: [] }))
for (const spec of specs) {
  const lightest = shards.reduce((a, b) => (b.size < a.size ? b : a))
  lightest.size += spec.size
  lightest.files.push(spec.file)
}

// With no file arguments Playwright runs the whole suite, so never print none.
const { files } = shards[shard - 1]
if (files.length === 0) {
  console.error(`Shard ${shard} of ${total} has no spec files`)
  process.exit(1)
}

const escapeRegExp = (file) => file.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
console.log(
  files
    .sort()
    .map((file) => `/e2e/${escapeRegExp(file)}$`)
    .join('\n'),
)
