import { describe, expect, it } from 'vitest'
import { cartonSize } from './carton-size'

describe('cartonSize', () => {
  it('reads back the way a merchant would write it', () => {
    expect(
      cartonSize({
        id: '1',
        name: 'Large',
        length: '60.0',
        width: '40.0',
        height: '40.0',
        dimensions_unit: 'cm',
      }),
    ).toBe('60 × 40 × 40 cm')
  })

  it('keeps a real decimal', () => {
    expect(
      cartonSize({
        id: '1',
        name: 'Small',
        length: '12.5',
        width: '9.0',
        height: '4.25',
        dimensions_unit: 'in',
      }),
    ).toBe('12.5 × 9 × 4.25 in')
  })

  // Half a box is not a size — better to say nothing than "60 × × cm".
  it('says nothing when a measurement is missing', () => {
    expect(
      cartonSize({
        id: '1',
        name: 'Partial',
        length: '60.0',
        width: null,
        height: '40.0',
        dimensions_unit: 'cm',
      }),
    ).toBeNull()
    expect(cartonSize({ id: '1', name: 'Bare' })).toBeNull()
  })

  it('omits an absent unit rather than trailing a space', () => {
    expect(cartonSize({ id: '1', name: 'Unitless', length: '10', width: '10', height: '10' })).toBe(
      '10 × 10 × 10',
    )
  })
})
