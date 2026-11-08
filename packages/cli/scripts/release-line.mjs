import { readdirSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '../../..')

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'))
}

/**
 * The packages that share the Spree version (the Changesets fixed group with
 * `@spree/sdk`) and that version, so `spree upgrade` can move a project off an
 * older numbering. Until every package in the group carries the same version
 * there is no shared line to move to, and the list is empty. Injected at build
 * time (tsup) and test time (vitest).
 *
 * @returns {{ packages: string[], version: string }}
 */
export function releaseLine() {
  const { fixed } = readJson(join(repoRoot, '.changeset/config.json'))
  const group = fixed.find((names) => names.includes('@spree/sdk')) ?? []
  const packagesDir = join(repoRoot, 'packages')
  const versions = new Map(
    readdirSync(packagesDir)
      .map((dir) => {
        try {
          return readJson(join(packagesDir, dir, 'package.json'))
        } catch {
          return undefined
        }
      })
      .filter((manifest) => manifest && group.includes(manifest.name))
      .map((manifest) => [manifest.name, manifest.version]),
  )
  const version = versions.get('@spree/sdk')
  const aligned = group.every((name) => versions.get(name) === version)
  return { packages: aligned ? group : [], version }
}
