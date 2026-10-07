import { describe, expect, it } from 'vitest'
import { rejectedExamples } from '../../sdk-core/scripts/openapi-examples'
import * as schemas from '../src/zod'

// Parses the whole API reference, which a busy CI runner can take well over
// the default five seconds to do.
const TIMEOUT = 30_000

describe('generated Zod schemas', () => {
  it(
    'accept every response recorded in the Admin API reference',
    () => {
      const { checked, rejections } = rejectedExamples('admin', schemas)

      expect(checked).toBeGreaterThan(0)
      expect(rejections).toEqual([])
    },
    TIMEOUT,
  )
})
