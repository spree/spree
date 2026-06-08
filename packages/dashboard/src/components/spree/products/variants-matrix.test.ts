import { describe, expect, it } from 'vitest'
import { composeOptionsText, type OptionTypeForLabel } from './variants-matrix'

const COLOR: OptionTypeForLabel = {
  name: 'color',
  label: 'Color',
  option_values: [
    { name: 'red', label: 'Red' },
    { name: 'matte-black', label: 'Matte Black' },
  ],
}

const SIZE: OptionTypeForLabel = {
  name: 'size',
  label: 'Size',
  option_values: [
    { name: 'xs', label: 'XS' },
    { name: 'l', label: 'L' },
  ],
}

describe('composeOptionsText', () => {
  it('returns an empty string when there are no options', () => {
    expect(composeOptionsText([], [COLOR, SIZE])).toBe('')
  })

  it('formats a single option as "Type: Value"', () => {
    expect(composeOptionsText([{ name: 'color', value: 'red' }], [COLOR])).toBe('Color: Red')
  })

  it('joins multiple options with ", " in input order', () => {
    expect(
      composeOptionsText(
        [
          { name: 'color', value: 'matte-black' },
          { name: 'size', value: 'xs' },
        ],
        [COLOR, SIZE],
      ),
    ).toBe('Color: Matte Black, Size: XS')
  })

  it('falls back to the type slug when the option type is not in the registry', () => {
    expect(composeOptionsText([{ name: 'material', value: 'steel' }], [COLOR])).toBe(
      'material: steel',
    )
  })

  it('falls back to the value slug when the value is not in the registry', () => {
    expect(composeOptionsText([{ name: 'color', value: 'fuchsia' }], [COLOR])).toBe(
      'Color: fuchsia',
    )
  })

  it('falls back per-component when the type matches but option_values is missing', () => {
    const colorNoValues: OptionTypeForLabel = { name: 'color', label: 'Color' }
    expect(composeOptionsText([{ name: 'color', value: 'red' }], [colorNoValues])).toBe(
      'Color: red',
    )
  })

  it('handles registry-empty input by returning bare slugs', () => {
    expect(
      composeOptionsText(
        [
          { name: 'color', value: 'red' },
          { name: 'size', value: 'xs' },
        ],
        [],
      ),
    ).toBe('color: red, size: xs')
  })

  it('preserves caller-provided option order (mirrors backend position ordering by registry)', () => {
    expect(
      composeOptionsText(
        [
          { name: 'size', value: 'l' },
          { name: 'color', value: 'red' },
        ],
        [COLOR, SIZE],
      ),
    ).toBe('Size: L, Color: Red')
  })
})
