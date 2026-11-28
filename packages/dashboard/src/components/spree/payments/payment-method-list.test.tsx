import type { PaymentMethod, PaymentMethodType } from '@spree/admin-sdk'
import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it, vi } from 'vitest'
import '../../../i18n-setup'
import { PaymentMethodList } from './payment-method-list'

vi.mock('@spree/dashboard-core', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@spree/dashboard-core')>()),
  usePermissions: () => ({ permissions: { can: () => true } }),
}))
vi.mock('../../../hooks/use-payment-methods', () => ({
  useUpdatePaymentMethod: () => ({ isPending: false, mutate: vi.fn() }),
  usePaymentMethodRuleTypes: () => ({ data: undefined }),
  usePaymentMethodRuleRecordNames: () => ({ data: [] }),
}))

function method(id: string, type: string, name: string) {
  return {
    id,
    type,
    name,
    description: null,
    active: true,
    storefront_visible: true,
    third_party: true,
    logo_url: null,
    docs_url: null,
    preferences: {},
    rules: [],
  } as unknown as PaymentMethod
}

const providerType = (type: string, label: string) =>
  ({ type, label, third_party: true }) as unknown as PaymentMethodType

function render(methods: PaymentMethod[]) {
  return renderToStaticMarkup(
    <PaymentMethodList
      methods={methods}
      onConfigure={vi.fn()}
      addAccountTypes={[providerType('stripe', 'Stripe'), providerType('bogus', 'Bogus')]}
      onAddAccount={vi.fn()}
    />,
  )
}

describe('the payment methods list', () => {
  it("lists a provider's accounts in one card that offers another", () => {
    const html = render([
      method('pm_1', 'stripe', 'Stripe EU'),
      method('pm_2', 'bogus', 'Credit Card'),
      method('pm_3', 'stripe', 'Stripe US'),
    ])

    expect(html.match(/data-provider="/g)).toHaveLength(2)
    const stripeCard = html.slice(
      html.indexOf('data-provider="stripe"'),
      html.indexOf('data-provider="bogus"'),
    )
    expect(stripeCard).toContain('Stripe EU')
    expect(stripeCard).toContain('Stripe US')
    expect(html.match(/Add another Stripe account/g)).toHaveLength(1)
    expect(stripeCard.indexOf('Add another Stripe account')).toBeGreaterThan(
      stripeCard.indexOf('Stripe US'),
    )
  })

  it("does not repeat the provider's name as a badge", () => {
    expect(render([method('pm_1', 'stripe', 'Stripe 2')]).match(/>Stripe</g)).toBeNull()
  })

  it('never offers another account of a test gateway', () => {
    expect(render([method('pm_1', 'bogus', 'Credit Card')])).not.toContain('Add another')
  })
})
