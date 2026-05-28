import type { JsonValueLinkResolver } from '@spree/dashboard-ui/spree/json-preview-drawer'

/**
 * Spree's prefixed-ID → admin-route mapping. Used by `<JsonPreviewDrawer>`
 * (and any other consumer of `JsonValueLinkResolver`) to turn IDs like
 * `or_abc123` or `prod_xyz789` that appear in a JSON payload into clickable
 * links to the corresponding admin page.
 *
 * Lives in `@spree/dashboard` (not `@spree/dashboard-ui`) so the design
 * system stays Spree-vocabulary-free. Plugins targeting a non-Spree backend
 * can pass their own resolver.
 */
const PREFIX_DESTINATIONS: Record<string, { to: string; paramName: string }> = {
  or: { to: '/$storeId/orders/$orderId', paramName: 'orderId' },
  prod: { to: '/$storeId/products/$productId', paramName: 'productId' },
  cus: { to: '/$storeId/customers/$customerId', paramName: 'customerId' },
}

const PREFIXED_ID_RE = /^([a-z]+(?:_[a-z]+)*)_([A-Za-z0-9]{6,})$/

/**
 * Build a `JsonValueLinkResolver` bound to the current store. Pass the
 * result to `<JsonPreviewDrawer resolveLink={...} />` (or via
 * `<PageHeader jsonPreview={{ resolveLink: ..., ... }} />`).
 */
export function spreeJsonLinkResolver(storeId: string): JsonValueLinkResolver {
  return (value) => {
    const match = PREFIXED_ID_RE.exec(value)
    if (!match) return null
    const dest = PREFIX_DESTINATIONS[match[1]]
    if (!dest) return null
    return { to: dest.to, params: { storeId, [dest.paramName]: value } }
  }
}
