import { describe, expect, it } from 'vitest'
import { filterPaymentMethodProviderTypes } from './payment-method'

describe('filterPaymentMethodProviderTypes', () => {
  it('removes custom payment source from the provider picker list', () => {
    const types = [
      {
        type: 'stripe',
        label: 'Stripe',
        schema: { type: 'object' as const, properties: {}, additionalProperties: false as const },
      },
      {
        type: 'custom_payment_source_method',
        label: 'Custom Payment Source Method',
        schema: { type: 'object' as const, properties: {}, additionalProperties: false as const },
      },
      {
        type: 'check',
        label: 'Check',
        schema: { type: 'object' as const, properties: {}, additionalProperties: false as const },
      },
    ]

    expect(filterPaymentMethodProviderTypes(types).map((t) => t.type)).toEqual(['stripe', 'check'])
  })
})
