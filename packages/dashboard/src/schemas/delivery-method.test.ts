import { describe, expect, it } from 'vitest'
import { DELIVERY_METHOD_DEFAULTS, deliveryMethodFormSchema } from './delivery-method'

const flatRate = (amounts: Record<string, string>) => ({
  ...DELIVERY_METHOD_DEFAULTS,
  name: 'Standard',
  calculator: { type: 'flat_rate', preferences: { amounts } },
})

function amountErrors(values: ReturnType<typeof flatRate>, carrierPricedProviders?: string[]) {
  const result = deliveryMethodFormSchema(carrierPricedProviders).safeParse(values)
  return result.success ? [] : result.error.issues.filter((issue) => issue.path[0] === 'calculator')
}

describe('deliveryMethodFormSchema calculator amounts', () => {
  it('asks a calculator-priced method for an amount in at least one currency', () => {
    expect(amountErrors(flatRate({}))).toHaveLength(1)
    expect(amountErrors(flatRate({ EUR: '' }))).toHaveLength(1)
    expect(amountErrors(flatRate({ EUR: '4.90' }))).toEqual([])
  })

  // The calculator stays on the record but its fields are hidden, so an empty amount must not block saving.
  it('asks nothing of a method priced by a carrier', () => {
    expect(amountErrors({ ...flatRate({}), rate_provider: 'easy_post' }, ['easy_post'])).toEqual([])
  })

  it('asks nothing when the default provider quotes the rates', () => {
    expect(amountErrors(flatRate({}), ['easy_post', ''])).toEqual([])
  })
})
