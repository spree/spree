import type { Fulfillment, Order } from '@spree/seller-sdk'
import type { TFunction } from 'i18next'

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
}

function addressBlock(order: Order): string {
  const address = order.shipping_address
  if (!address) return ''

  return [
    [address.first_name, address.last_name].filter(Boolean).join(' '),
    address.company,
    address.address1,
    address.address2,
    [address.city, address.state_name ?? address.state_code, address.postal_code]
      .filter(Boolean)
      .join(', '),
    address.country_name || address.country_code,
  ]
    .filter(Boolean)
    .map((line) => escapeHtml(String(line)))
    .join('<br>')
}

function itemRows(fulfillment: Fulfillment): string {
  return (fulfillment.fulfillment_items ?? [])
    .map(
      (item) => `
        <tr>
          <td>
            ${escapeHtml(item.name ?? item.id)}
            ${item.options_text ? `<div class="muted">${escapeHtml(item.options_text)}</div>` : ''}
          </td>
          <td class="qty">${item.quantity}</td>
        </tr>`,
    )
    .join('')
}

/**
 * Opens a printable packing slip for one parcel in a new window.
 *
 * A generated document rather than a panel route: the panel's own chrome
 * would print with an in-app page, and everything the slip needs is already
 * loaded on the order screen. No prices — a packing slip says what is in the
 * box, not what it cost.
 */
export function printPackingSlip(order: Order, fulfillment: Fulfillment, t: TFunction): void {
  const title = t('orders.fulfillments.packing_slip_title', { number: order.number })

  const html = `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>${escapeHtml(title)}</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; margin: 40px; color: #111; }
  h1 { font-size: 20px; margin: 0 0 4px; }
  .muted { color: #666; font-size: 12px; }
  .columns { display: flex; gap: 48px; margin: 24px 0; }
  h2 { font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; color: #666; margin: 0 0 6px; }
  table { width: 100%; border-collapse: collapse; margin-top: 8px; }
  th { text-align: left; font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; color: #666;
       border-bottom: 1px solid #ddd; padding: 6px 0; }
  td { padding: 8px 0; border-bottom: 1px solid #eee; font-size: 14px; vertical-align: top; }
  .qty { text-align: right; width: 60px; }
</style>
</head>
<body>
  <h1>${escapeHtml(title)}</h1>
  <div class="muted">${escapeHtml(fulfillment.number ?? '')}</div>

  <div class="columns">
    <div>
      <h2>${escapeHtml(t('orders.fulfillments.ship_to'))}</h2>
      <div>${addressBlock(order)}</div>
    </div>
    <div>
      <h2>${escapeHtml(t('orders.fulfillments.ships_from_label'))}</h2>
      <div>${escapeHtml(fulfillment.stock_location_name ?? '')}</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>${escapeHtml(t('orders.items'))}</th>
        <th class="qty">${escapeHtml(t('orders.columns.quantity'))}</th>
      </tr>
    </thead>
    <tbody>${itemRows(fulfillment)}</tbody>
  </table>
</body>
</html>`

  const printWindow = window.open('', '_blank')
  if (!printWindow) return

  printWindow.document.write(html)
  printWindow.document.close()
  printWindow.focus()
  printWindow.print()
}
