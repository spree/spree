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

const floors = new Map()
for (const dir of process.argv.slice(2)) {
  const { peerDependencies = {} } = JSON.parse(
    fs.readFileSync(path.join(dir, 'package.json'), 'utf8'),
  )
  for (const [name, range] of Object.entries(peerDependencies)) {
    if (name.startsWith('@spree/') || range.startsWith('workspace:')) continue
    const floor = semver.minVersion(range).version
    if (!floors.has(name) || semver.gt(floor, floors.get(name))) floors.set(name, floor)
  }
}

console.log([...floors].map(([name, version]) => `${name}@${version}`).join(' '))
