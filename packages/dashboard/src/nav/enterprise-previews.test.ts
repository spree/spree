import { __getNavEntries, getPluginRoutes, matchPluginRoute } from '@spree/dashboard-core'
import { describe, expect, it } from 'vitest'
import { ENTERPRISE_PREVIEWS_ENABLED, enterprisePreviews } from '../lib/enterprise-previews'
import './default'
import './settings'
import './enterprise-previews'

const childKeys = (parentKey: string) =>
  __getNavEntries()
    .find((entry) => entry.key === parentKey)
    ?.children?.map((child) => child.key) ?? []

// An installation that turns the previews off registers none of them.
describe.skipIf(!ENTERPRISE_PREVIEWS_ENABLED)('Enterprise previews', () => {
  it('places each preview where its Enterprise page will be', () => {
    expect(childKeys('orders')).toContain('orders.quotes')
    expect(childKeys('companies')).toContain('companies.onboarding')
    expect(childKeys('sellers')).toContain('sellers.shopify')
    expect(childKeys('inventory')).toContain('inventory.lots')
    expect(matchPluginRoute('settings/audit-log', getPluginRoutes())?.entry.key).toBe(
      'settings.audit-log',
    )
  })

  it('takes down the entry and the page when Enterprise replaces a preview', () => {
    enterprisePreviews.remove('orders.quotes')

    expect(childKeys('orders')).not.toContain('orders.quotes')
    expect(matchPluginRoute('orders/quotes', getPluginRoutes())).toBeNull()
    expect(childKeys('sellers')).toContain('sellers.shopify')
  })
})
