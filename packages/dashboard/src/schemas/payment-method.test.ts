import { describe, expect, it } from 'vitest'
import { defaultPaymentMethodName, filterPaymentMethodProviderTypes } from './payment-method'

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

  // A second record of a provider is how a store runs a second account.
  it('keeps providers this store already has installed', () => {
    const schema = { type: 'object' as const, properties: {}, additionalProperties: false as const }
    const types = [
      { type: 'stripe', label: 'Stripe', schema, installed_count: 1 },
      { type: 'check', label: 'Check', schema, installed_count: 0 },
    ]

    expect(filterPaymentMethodProviderTypes(types).map((t) => t.type)).toEqual(['stripe', 'check'])
  })
})

describe('defaultPaymentMethodName', () => {
  it('uses the provider label while no method has it', () => {
    expect(defaultPaymentMethodName('Stripe', ['Check'])).toBe('Stripe')
  })

  it('numbers past every name the store already uses', () => {
    expect(defaultPaymentMethodName('Stripe', ['Stripe', 'stripe 2', 'Stripe 3'])).toBe('Stripe 4')
  })

  it('skips a numbered name already taken by another method', () => {
    expect(defaultPaymentMethodName('Stripe', ['Stripe 2'])).toBe('Stripe')
    expect(defaultPaymentMethodName('Stripe', ['Stripe', 'Stripe 2'])).toBe('Stripe 3')
  })
})
