// Writes the JSON Schema for spree.config.yml from the built engine, so the
// file editors validate against is the same definition the CLI validates with.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { toJsonSchema } from '../dist/config/index.js'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const schema = toJsonSchema()

// Left alone when only formatting would differ: the committed copies are
// formatted by the repository's linter, and a build must not undo that.
function write(target) {
  if (existsSync(target)) {
    try {
      if (JSON.stringify(JSON.parse(readFileSync(target, 'utf-8'))) === JSON.stringify(schema))
        return
    } catch {
      // unreadable or corrupt: rewrite it
    }
  }
  mkdirSync(dirname(target), { recursive: true })
  writeFileSync(target, `${JSON.stringify(schema, null, 2)}\n`)
  console.log(`wrote ${target}`)
}

write(resolve(root, 'schemas/spree-config.json'))

// Inside the monorepo, also refresh the copy the docs site publishes — the
// URL every generated file points editors at.
const published = resolve(root, '../../docs/schemas/spree-config/1.json')
if (existsSync(dirname(dirname(published)))) write(published)
