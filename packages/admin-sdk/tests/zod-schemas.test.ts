import { describe, expect, it } from 'vitest'
import { rejectedExamples } from '../../sdk-core/scripts/openapi-examples'
import * as schemas from '../src/zod'

describe('generated Zod schemas', () => {
  it('accept every response recorded in the Admin API reference', () => {
    const { checked, rejections } = rejectedExamples('admin', schemas)

    expect(checked).toBeGreaterThan(0)
    expect(rejections).toEqual([])
  })
})
