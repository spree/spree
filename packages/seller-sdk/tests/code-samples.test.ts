import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { endpointsWithoutSample, unmarkedExamples } from '../../sdk-core/scripts/code-samples'

// Parses the whole API reference, which a busy CI runner can take well over
// the default five seconds to do.
const TIMEOUT = 30_000

describe('Seller SDK examples', () => {
  it(
    'appear on every endpoint in the Seller API reference',
    () => {
      expect(endpointsWithoutSample('seller', 'Spree Seller SDK')).toEqual([])
    },
    TIMEOUT,
  )

  it('mark the code the API reference shows', () => {
    const examplesRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../examples')

    expect(unmarkedExamples(examplesRoot)).toEqual([])
  })
})
