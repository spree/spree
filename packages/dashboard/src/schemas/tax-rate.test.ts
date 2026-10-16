import { describe, expect, it } from 'vitest'
import { TAX_RATE_DEFAULTS, taxRateFormSchema } from './tax-rate'

const valid = { ...TAX_RATE_DEFAULTS, name: 'VAT', tax_category_id: 'tc_1' }

function rateErrors(ratePercent: string) {
  const result = taxRateFormSchema.safeParse({ ...valid, rate_percent: ratePercent })
  return result.success
    ? []
    : result.error.issues.filter((issue) => issue.path[0] === 'rate_percent')
}

describe('taxRateFormSchema rate_percent', () => {
  it('takes a percentage with up to three decimals', () => {
    expect(rateErrors('7.125')).toEqual([])
    expect(rateErrors('100')).toEqual([])
  })

  it('refuses a fourth decimal, which the server could not keep', () => {
    expect(rateErrors('7.1255')).toHaveLength(1)
  })

  it('refuses a rate above 100', () => {
    expect(rateErrors('100.5')).toHaveLength(1)
  })

  // The later checks used to compare a blank value and throw, crashing the form.
  it('reports a blank or malformed rate instead of throwing', () => {
    expect(rateErrors('').length).toBeGreaterThan(0)
    expect(rateErrors('.5').length).toBeGreaterThan(0)
  })
})
