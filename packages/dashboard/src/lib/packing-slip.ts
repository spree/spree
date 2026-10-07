import type { Fulfillment, LineItem, Order } from '@spree/admin-sdk'
import { fulfillmentItemRows } from '@spree/dashboard-core'
import type { TFunction } from 'i18next'
import i18n from 'i18next'
import { formatAmount } from '../schemas/order'

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
}

function formatDate(iso: string | null | undefined): string | null {
  if (!iso) return null
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return null

  return date.toLocaleDateString(i18n.language, { year: 'numeric', month: 'long', day: 'numeric' })
}

/** Renders a stacked list of address lines, dropping the empty ones. */
function addressLines(lines: Array<string | null | undefined>): string {
  return lines
    .filter((line): line is string => Boolean(line?.trim()))
    .map((line) => escapeHtml(line))
    .join('<br>')
}

function shipToBlock(order: Order): string {
  const address = order.shipping_address
  if (!address) return ''

  return addressLines([
    address.full_name || [address.first_name, address.last_name].filter(Boolean).join(' '),
    address.company,
    address.address1,
    address.address2,
    [address.city, address.state_name ?? address.state_code, address.postal_code]
      .filter(Boolean)
      .join(', '),
    address.country_name || address.country_code,
    address.phone,
    order.email,
  ])
}

function shipsFromBlock(fulfillment: Fulfillment): string {
  const location = fulfillment.stock_location
  if (!location) return ''

  return addressLines([
    location.name,
    location.company,
    location.address1,
    location.address2,
    [
      location.city,
      location.state_name ?? location.state_text ?? location.state_code,
      location.zipcode,
    ]
      .filter(Boolean)
      .join(', '),
    location.country_name || location.country_code,
  ])
}

/** One printable product line, joined to its line item for image, SKU and price. */
interface PackingSlipRow {
  key: string
  name: string
  optionsText: string | null
  thumbnailUrl: string | null
  sku: string | null
  displayUnitPrice: string | null
  displayLineTotal: string | null
  quantity: number
}

interface SummaryLine {
  label: string
  value: string
  emphasized: boolean
}

interface PackingSlipData {
  rows: PackingSlipRow[]
  hasPricing: boolean
  hasSku: boolean
  summary: SummaryLine[]
}

function buildRows(order: Order, fulfillment: Fulfillment): PackingSlipRow[] {
  const currency = order.currency
  const byId = new Map<string, LineItem>((order.items ?? []).map((item) => [item.id, item]))

  return fulfillmentItemRows(fulfillment, order.items ?? []).map((row) => {
    const lineItem = byId.get(row.key)
    const unitPrice = lineItem ? Number(lineItem.price) : Number.NaN
    const canPrice = lineItem != null && Number.isFinite(unitPrice)

    // Prefer the server's formatted total when this parcel holds the whole
    // line; compute per-parcel only when a partial quantity ships, so the
    // number reflects what is actually in the box.
    const lineTotal = !canPrice
      ? null
      : row.quantity === lineItem.quantity
        ? lineItem.display_total
        : formatAmount(unitPrice * row.quantity, currency)

    return {
      key: row.key,
      name: row.name,
      optionsText: row.optionsText,
      thumbnailUrl: row.thumbnailUrl,
      sku: lineItem?.variant?.sku ?? null,
      displayUnitPrice: lineItem?.display_price ?? row.displayPrice,
      displayLineTotal: lineTotal,
      quantity: row.quantity,
    }
  })
}

/**
 * The bottom-right totals. When this fulfillment holds the entire order the
 * server's order-level totals are exact, so shipping/discount/tax appear. A
 * partial parcel only gets the value of the goods it carries — putting an
 * order-wide shipping charge on one box of several would mislead.
 */
function buildSummary(
  order: Order,
  rows: PackingSlipRow[],
  fulfilledQuantity: number,
  t: TFunction,
): SummaryLine[] {
  const key = (name: string) => t(`admin.orders.detail.fulfillments.${name}`)
  const isWholeOrder =
    (order.fulfillments?.length ?? 0) <= 1 && fulfilledQuantity === order.total_quantity

  if (isWholeOrder) {
    const lines: SummaryLine[] = [
      { label: key('packing_slip_subtotal'), value: order.display_item_total, emphasized: false },
    ]
    if (Number(order.delivery_total) !== 0) {
      lines.push({
        label: key('packing_slip_shipping'),
        value: order.display_delivery_total,
        emphasized: false,
      })
    }
    if (Number(order.discount_total) !== 0) {
      lines.push({
        label: key('packing_slip_discount'),
        value: order.display_discount_total,
        emphasized: false,
      })
    }
    if (Number(order.tax_total) !== 0) {
      lines.push({
        label: key('packing_slip_tax'),
        value: order.display_tax_total,
        emphasized: false,
      })
    }
    lines.push({ label: key('packing_slip_total'), value: order.display_total, emphasized: true })
    return lines
  }

  const subtotal = (order.items ?? []).reduce((sum, item) => {
    const row = rows.find((candidate) => candidate.key === item.id)
    if (!row) return sum
    const price = Number(item.price)
    return Number.isFinite(price) ? sum + price * row.quantity : sum
  }, 0)
  const formatted = formatAmount(subtotal, order.currency)

  return [
    { label: key('packing_slip_subtotal'), value: formatted, emphasized: false },
    { label: key('packing_slip_total'), value: formatted, emphasized: true },
  ]
}

function collectData(order: Order, fulfillment: Fulfillment, t: TFunction): PackingSlipData {
  const rows = buildRows(order, fulfillment)
  const fulfilledQuantity = rows.reduce((sum, row) => sum + row.quantity, 0)
  const hasPricing = rows.some(
    (row) => row.displayLineTotal != null || row.displayUnitPrice != null,
  )

  return {
    rows,
    hasPricing,
    hasSku: rows.some((row) => Boolean(row.sku)),
    summary: hasPricing ? buildSummary(order, rows, fulfilledQuantity, t) : [],
  }
}

function thumbnailCell(row: PackingSlipRow): string {
  const image = row.thumbnailUrl
    ? `<img src="${escapeHtml(row.thumbnailUrl)}" alt="">`
    : '<div class="thumb-placeholder"></div>'

  return `<td class="col-thumb">${image}</td>`
}

function productCell(row: PackingSlipRow, showSku: boolean): string {
  const secondary = [row.optionsText, showSku && row.sku ? `SKU ${row.sku}` : null]
    .filter((value): value is string => Boolean(value))
    .map((value) => escapeHtml(value))
    .join(' · ')

  return `<td class="col-product">
    <div class="product-name">${escapeHtml(row.name)}</div>
    ${secondary ? `<div class="product-meta">${secondary}</div>` : ''}
  </td>`
}

function itemRows(data: PackingSlipData): string {
  return data.rows
    .map((row) => {
      const cells = [thumbnailCell(row), productCell(row, data.hasSku)]

      if (data.hasPricing) {
        cells.push(`<td class="col-price">${escapeHtml(row.displayUnitPrice ?? '—')}</td>`)
      }
      cells.push(`<td class="col-qty">${row.quantity}</td>`)
      if (data.hasPricing) {
        cells.push(`<td class="col-total">${escapeHtml(row.displayLineTotal ?? '—')}</td>`)
      }

      return `<tr>${cells.join('')}</tr>`
    })
    .join('')
}

function tableHead(data: PackingSlipData, t: TFunction): string {
  const cells = [
    '<th class="col-thumb"></th>',
    `<th class="col-product">${escapeHtml(t('admin.orders.edit.columns.product'))}</th>`,
  ]

  if (data.hasPricing) {
    cells.push(
      `<th class="col-price">${escapeHtml(t('admin.orders.edit.columns.unit_price'))}</th>`,
    )
  }
  cells.push(`<th class="col-qty">${escapeHtml(t('admin.fields.quantity.label'))}</th>`)
  if (data.hasPricing) {
    cells.push(
      `<th class="col-total">${escapeHtml(t('admin.orders.edit.columns.line_total'))}</th>`,
    )
  }

  return `<tr>${cells.join('')}</tr>`
}

function summaryBlock(data: PackingSlipData): string {
  if (data.summary.length === 0) return ''

  const rows = data.summary
    .map(
      (line) => `
      <div class="summary-row${line.emphasized ? ' summary-row-total' : ''}">
        <span class="summary-label">${escapeHtml(line.label)}</span>
        <span class="summary-value">${escapeHtml(line.value)}</span>
      </div>`,
    )
    .join('')

  return `<div class="summary"><div class="summary-inner">${rows}</div></div>`
}

/**
 * Opens a printable packing slip for one fulfillment in a new window.
 *
 * Deliberately a generated document rather than an admin route: the admin
 * shell (sidebar, top bar) would print with an in-app page, and everything
 * the slip needs is already loaded on the order screen.
 */
export function printPackingSlip(order: Order, fulfillment: Fulfillment, t: TFunction): void {
  const data = collectData(order, fulfillment, t)

  const title = t('admin.orders.detail.fulfillments.packing_slip_title', { number: order.number })
  const shipTo = shipToBlock(order)
  const shipsFrom = shipsFromBlock(fulfillment)
  const orderDate = formatDate(order.completed_at ?? order.created_at)

  const metaLines = [
    `<div class="meta-line">${escapeHtml(
      t('admin.orders.detail.fulfillments.packing_slip_order', { number: order.number }),
    )}</div>`,
    fulfillment.number
      ? `<div class="meta-line">${escapeHtml(
          t('admin.orders.detail.fulfillments.packing_slip_fulfillment', {
            number: fulfillment.number,
          }),
        )}</div>`
      : '',
    orderDate ? `<div class="meta-date">${escapeHtml(orderDate)}</div>` : '',
  ]
    .filter(Boolean)
    .join('')

  const html = `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>${escapeHtml(title)}</title>
<style>
  :root {
    --ink: #111827;
    --muted: #6b7280;
    --line: #e5e7eb;
    --subtle: #f9fafb;
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    color: var(--ink);
    font-size: 13px;
    line-height: 1.5;
    background: #fff;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .sheet { max-width: 820px; margin: 0 auto; padding: 48px 40px; }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 24px;
    padding-bottom: 24px;
    border-bottom: 2px solid var(--ink);
  }
  .doc-title {
    font-size: 22px;
    font-weight: 700;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    margin: 0;
  }
  .header-right { text-align: right; }
  .meta-line { font-size: 14px; font-weight: 600; }
  .meta-line + .meta-line { margin-top: 2px; }
  .meta-date { margin-top: 6px; color: var(--muted); font-size: 12px; }

  .addresses {
    display: flex;
    gap: 64px;
    margin: 28px 0 32px;
  }
  .addr { flex: 1; }
  .label {
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.09em;
    text-transform: uppercase;
    color: var(--muted);
    margin-bottom: 8px;
  }
  .addr-body { color: var(--ink); }

  table { width: 100%; border-collapse: collapse; }
  thead { display: table-header-group; }
  th {
    text-align: left;
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: var(--muted);
    border-bottom: 1px solid var(--line);
    padding: 0 12px 10px;
  }
  td {
    padding: 12px;
    border-bottom: 1px solid var(--line);
    vertical-align: middle;
    page-break-inside: avoid;
    break-inside: avoid;
  }
  tr { page-break-inside: avoid; break-inside: avoid; }

  .col-thumb { width: 60px; padding-right: 0; }
  .col-price, .col-total, .col-qty { text-align: right; white-space: nowrap; }
  .col-qty { width: 56px; }
  .col-price, .col-total { width: 96px; }
  .col-total { font-weight: 600; }

  .col-thumb img,
  .thumb-placeholder {
    width: 48px;
    height: 48px;
    border-radius: 6px;
    background: var(--subtle);
    border: 1px solid var(--line);
    object-fit: contain;
    display: block;
  }

  .product-name { font-weight: 600; }
  .product-meta { margin-top: 2px; color: var(--muted); font-size: 12px; }

  .summary {
    display: flex;
    justify-content: flex-end;
    margin-top: 24px;
    page-break-inside: avoid;
    break-inside: avoid;
  }
  .summary-inner { width: 280px; }
  .summary-row {
    display: flex;
    justify-content: space-between;
    padding: 6px 12px;
    color: var(--muted);
  }
  .summary-row .summary-value { color: var(--ink); }
  .summary-row-total {
    margin-top: 4px;
    padding-top: 12px;
    border-top: 1px solid var(--ink);
    font-size: 16px;
    font-weight: 700;
    color: var(--ink);
  }

  .footer {
    margin-top: 48px;
    padding-top: 16px;
    border-top: 1px solid var(--line);
    text-align: center;
    color: var(--muted);
    font-size: 12px;
  }

  @page { size: A4; margin: 16mm; }
  @media print {
    .sheet { max-width: none; padding: 0; }
    body { font-size: 12px; }
  }
</style>
</head>
<body>
  <div class="sheet">
    <header class="header">
      <h1 class="doc-title">${escapeHtml(title)}</h1>
      <div class="header-right">${metaLines}</div>
    </header>

    <section class="addresses">
      ${
        shipTo
          ? `<div class="addr">
        <div class="label">${escapeHtml(t('admin.orders.detail.fulfillments.ship_to'))}</div>
        <div class="addr-body">${shipTo}</div>
      </div>`
          : ''
      }
      ${
        shipsFrom
          ? `<div class="addr">
        <div class="label">${escapeHtml(t('admin.orders.detail.fulfillments.ships_from'))}</div>
        <div class="addr-body">${shipsFrom}</div>
      </div>`
          : ''
      }
    </section>

    <table>
      <thead>${tableHead(data, t)}</thead>
      <tbody>${itemRows(data)}</tbody>
    </table>

    ${summaryBlock(data)}

    <footer class="footer">${escapeHtml(t('admin.orders.detail.fulfillments.packing_slip_footer'))}</footer>
  </div>
</body>
</html>`

  const printWindow = window.open('', '_blank')
  if (!printWindow) return

  printWindow.document.write(html)
  printWindow.document.close()
  printWindow.focus()
  printWindow.print()
}
