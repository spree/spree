import { describe, expect, it } from 'vitest'
import { addVariantsToLines, type VariantLine } from './variant-line-editor'

const variant = (id: string) => ({ id, sku: id.toUpperCase(), product_name: `Product ${id}` })

describe('addVariantsToLines', () => {
  it('adds every variant of a multi-select, not just the first', () => {
    const picked = [variant('a'), variant('b'), variant('c')]

    const lines = addVariantsToLines([], picked, false)

    expect(lines.map((line) => line.variant.id)).toEqual(['a', 'b', 'c'])
    expect(lines.every((line) => line.quantity === 1)).toBe(true)
  })

  it('keeps lines already on the document and appends the new ones', () => {
    const existing: VariantLine[] = [{ variant: variant('a'), quantity: 4 }]

    const lines = addVariantsToLines(existing, [variant('b'), variant('c')], false)

    expect(lines.map((line) => line.variant.id)).toEqual(['a', 'b', 'c'])
    expect(lines[0].quantity).toBe(4)
  })

  it('counts a re-picked variant up instead of duplicating its row', () => {
    const existing: VariantLine[] = [{ variant: variant('a'), quantity: 2 }]

    const lines = addVariantsToLines(existing, [variant('a'), variant('b')], false)

    expect(lines).toHaveLength(2)
    expect(lines[0].quantity).toBe(3)
  })

  it('counts a variant repeated inside one batch onto a single line', () => {
    const lines = addVariantsToLines([], [variant('a'), variant('b'), variant('a')], false)

    expect(lines.map((line) => line.variant.id)).toEqual(['a', 'b'])
    expect(lines[0].quantity).toBe(2)
  })

  it('seeds a cost only where the document has one', () => {
    expect(addVariantsToLines([], [variant('a')], true)[0].unitCost).toBe('0.00')
    expect(addVariantsToLines([], [variant('a')], false)[0].unitCost).toBeUndefined()
  })

  it('leaves the lines untouched when nothing was picked', () => {
    const existing: VariantLine[] = [{ variant: variant('a'), quantity: 1 }]
    expect(addVariantsToLines(existing, [], false)).toBe(existing)
  })
})
