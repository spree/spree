import { readdirSync, readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { parse } from 'yaml'

const HTTP_METHODS = ['get', 'post', 'put', 'patch', 'delete']
const PACKAGE_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

type CodeSample = { label?: string; source?: string }

// Parses the whole API reference, which a busy CI runner can take well over
// the default five seconds to do.
const TIMEOUT = 30_000

describe('Seller SDK examples', () => {
  it(
    'appear on every endpoint in the Seller API reference',
    () => {
      const spec = parse(
        readFileSync(path.resolve(PACKAGE_ROOT, '../../docs/api-reference/seller.yaml'), 'utf8'),
      )
      const missing: string[] = []

      for (const [route, operations] of Object.entries<
        Record<string, { 'x-codeSamples'?: CodeSample[] }>
      >(spec.paths)) {
        for (const [method, operation] of Object.entries(operations)) {
          if (!HTTP_METHODS.includes(method)) continue

          const hasSample = operation['x-codeSamples']?.some(
            (sample) => sample.label === 'Spree Seller SDK' && sample.source?.trim(),
          )
          if (!hasSample) missing.push(`${method.toUpperCase()} ${route}`)
        }
      }

      expect(missing).toEqual([])
    },
    TIMEOUT,
  )

  // The API reference shows only the code between these markers, and a
  // formatter can drop a trailing marker along with the code around it.
  it('mark the code the API reference shows', () => {
    const examplesRoot = path.join(PACKAGE_ROOT, 'examples')
    const unmarked = readdirSync(examplesRoot, { recursive: true, encoding: 'utf8' })
      .filter((file) => file.endsWith('.ts'))
      .filter((file) => {
        const source = readFileSync(path.join(examplesRoot, file), 'utf8')
        return !/\/\/ region:example\n[\s\S]+?\/\/ endregion:example/.test(source)
      })

    expect(unmarked).toEqual([])
  })
})
