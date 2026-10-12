import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { parse } from 'yaml'

const HTTP_METHODS = ['get', 'post', 'put', 'patch', 'delete']

describe('Seller API reference', () => {
  it('shows a Seller SDK example on every endpoint', () => {
    const spec = parse(
      readFileSync(
        path.resolve(
          path.dirname(fileURLToPath(import.meta.url)),
          '../../../docs/api-reference/seller.yaml',
        ),
        'utf8',
      ),
    )
    const missing: string[] = []

    for (const [route, operations] of Object.entries<
      Record<string, { 'x-codeSamples'?: unknown[] }>
    >(spec.paths)) {
      for (const [method, operation] of Object.entries(operations)) {
        if (!HTTP_METHODS.includes(method)) continue
        if (!operation['x-codeSamples']?.length) missing.push(`${method.toUpperCase()} ${route}`)
      }
    }

    expect(missing).toEqual([])
  })
})
