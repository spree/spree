#!/usr/bin/env node
// Prints the oldest version of each third-party peer dependency that every
// given package accepts, as `name@version` arguments for `pnpm add`. CI
// installs these into a scaffolded app to prove the published peer ranges
// still build, not only the catalog versions the workspace tests.
//
// Usage: node scripts/peer-floors.mjs packages/dashboard packages/dashboard-core ...
import fs from 'node:fs'
import path from 'node:path'
import semver from 'semver'

const ranges = new Map()
for (const dir of process.argv.slice(2)) {
  const { peerDependencies = {} } = JSON.parse(
    fs.readFileSync(path.join(dir, 'package.json'), 'utf8'),
  )
  for (const [name, range] of Object.entries(peerDependencies)) {
    if (name.startsWith('@spree/') || range.startsWith('workspace:')) continue
    if (!semver.validRange(range)) {
      console.error(`${dir}: peer range ${name}@"${range}" is not a semver range`)
      process.exit(1)
    }
    ranges.set(name, [...(ranges.get(name) ?? []), range])
  }
}

const floors = []
for (const [name, list] of ranges) {
  const floor = list
    .map((range) => semver.minVersion(range).version)
    .reduce((a, b) => (semver.gt(a, b) ? a : b))
  const rejecting = list.filter((range) => !semver.satisfies(floor, range))
  if (rejecting.length > 0) {
    console.error(`${name}@${floor} falls outside peer ranges ${rejecting.join(', ')}`)
    process.exit(1)
  }
  floors.push(`${name}@${floor}`)
}

console.log(floors.join(' '))
