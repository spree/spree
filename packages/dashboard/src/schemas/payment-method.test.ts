import { describe, expect, it } from 'vitest'
import { filterPaymentMethodProviderTypes } from './payment-method'

describe('filterPaymentMethodProviderTypes', () => {
  it('removes custom payment source from the provider picker list', () => {
    const types = [
      { type: 'stripe', label: 'Stripe', preference_schema: [] },
      {
        type: 'custom_payment_source_method',
        label: 'Custom Payment Source Method',
        preference_schema: [],
      },
      { type: 'check', label: 'Check', preference_schema: [] },
    ]

    expect(filterPaymentMethodProviderTypes(types).map((t) => t.type)).toEqual(['stripe', 'check'])
  })
})
