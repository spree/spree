import { describe, expect, it } from 'vitest'
import { rejectedExamples } from '../../sdk-core/scripts/openapi-examples'
import * as schemas from '../src/zod'

// Parses a whole API reference, which outruns the default 5-second limit on a
// busy CI runner.
const PARSE_TIMEOUT = 30_000

describe('generated Zod schemas', () => {
  it('accept every response recorded in the Seller API reference', {
    timeout: PARSE_TIMEOUT,
  }, () => {
    const { checked, rejections } = rejectedExamples('seller', schemas)

    expect(checked).toBeGreaterThan(0)
    expect(rejections).toEqual([])
  })
})
