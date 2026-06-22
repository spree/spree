import * as fs from 'node:fs'
import * as path from 'node:path'

/**
 * Generates the discriminated union of Spree webhook events
 * (`src/webhook-events.generated.ts`) from a curated catalog of event names
 * mapped to the generated Store API types.
 *
 * Why a curated catalog and not a scrape of the Ruby source: event *names* are
 * defined in two ways in `Spree::Publishable` — implicit lifecycle events
 * (`<prefix>.created|updated|deleted` from `publishes_lifecycle_events`) and
 * explicit `publish_event('order.completed')` string literals scattered across
 * models and services. There is no single machine-readable list. The *payload
 * shapes*, however, are the V3 serializers, which already drive the generated
 * types in `src/types/generated`. So we curate the (name → type) table here and
 * derive the payload types from the generated types — names stay explicit and
 * reviewable, shapes stay auto-synced with the serializers.
 *
 * When the backend adds or renames an event, update CATALOG below. The mapped
 * type name must match a file in `src/types/generated`.
 *
 * Run: `pnpm generate:webhook-events`
 */

const TYPES_DIR = path.resolve(import.meta.dirname, '../src/types/generated')
const OUT_FILE = path.resolve(import.meta.dirname, '../src/webhook-events.generated.ts')

/**
 * The event catalog: maps each emitted event name to the generated type its
 * `data` payload carries. Mirrors `Spree::Publishable` (lifecycle events) and
 * the `publish_event(...)` calls across `spree/core` and `spree/api`.
 *
 * Grouped by resource for readability. Lifecycle triples
 * (`created`/`updated`/`deleted`) are expanded by `lifecycle()`.
 */
const LIFECYCLE = (prefix: string, type: string): Array<[string, string]> =>
  ['created', 'updated', 'deleted'].map((verb) => [`${prefix}.${verb}`, type])

const CATALOG: Array<[string, string]> = [
  // ── Lifecycle events (publishes_lifecycle_events) ──────────────────────────
  ...LIFECYCLE('order', 'Order'),
  ...LIFECYCLE('line_item', 'LineItem'),
  ...LIFECYCLE('product', 'Product'),
  ...LIFECYCLE('variant', 'Variant'),
  ...LIFECYCLE('price', 'Price'),
  ...LIFECYCLE('payment', 'Payment'),
  ...LIFECYCLE('payment_session', 'PaymentSession'),
  ...LIFECYCLE('payment_setup_session', 'PaymentSetupSession'),
  ...LIFECYCLE('refund', 'Refund'),
  ...LIFECYCLE('shipment', 'Fulfillment'),
  ...LIFECYCLE('stock_reservation', 'StockReservation'),
  ...LIFECYCLE('return_authorization', 'ReturnAuthorization'),
  ...LIFECYCLE('store_credit', 'StoreCredit'),
  ...LIFECYCLE('gift_card', 'GiftCard'),
  ...LIFECYCLE('gift_card_batch', 'GiftCardBatch'),
  ...LIFECYCLE('promotion', 'Promotion'),
  ...LIFECYCLE('digital', 'Digital'),
  ...LIFECYCLE('digital_link', 'DigitalLink'),
  ...LIFECYCLE('wishlist', 'Wishlist'),
  ...LIFECYCLE('wished_item', 'WishlistItem'),
  ...LIFECYCLE('newsletter_subscriber', 'NewsletterSubscriber'),

  // ── Order ──────────────────────────────────────────────────────────────────
  ['order.completed', 'Order'],
  ['order.paid', 'Order'],
  ['order.canceled', 'Order'],
  ['order.resumed', 'Order'],
  ['order.approved', 'Order'],
  ['order.shipped', 'Order'],

  // ── Payment ──────────────────────────────────────────────────────────────
  ['payment.completed', 'Payment'],
  ['payment.paid', 'Payment'],
  ['payment.voided', 'Payment'],

  // ── Payment session ────────────────────────────────────────────────────────
  ['payment_session.processing', 'PaymentSession'],
  ['payment_session.completed', 'PaymentSession'],
  ['payment_session.failed', 'PaymentSession'],
  ['payment_session.canceled', 'PaymentSession'],
  ['payment_session.expired', 'PaymentSession'],

  // ── Payment setup session ────────────────────────────────────────────────
  ['payment_setup_session.processing', 'PaymentSetupSession'],
  ['payment_setup_session.completed', 'PaymentSetupSession'],
  ['payment_setup_session.failed', 'PaymentSetupSession'],
  ['payment_setup_session.canceled', 'PaymentSetupSession'],
  ['payment_setup_session.expired', 'PaymentSetupSession'],

  // ── Product ──────────────────────────────────────────────────────────────
  ['product.activated', 'Product'],
  ['product.archived', 'Product'],
  ['product.back_in_stock', 'Product'],
  ['product.out_of_stock', 'Product'],

  // ── Shipment ─────────────────────────────────────────────────────────────
  ['shipment.shipped', 'Fulfillment'],
  ['shipment.canceled', 'Fulfillment'],
  ['shipment.resumed', 'Fulfillment'],

  // ── Gift card ────────────────────────────────────────────────────────────
  ['gift_card.redeemed', 'GiftCard'],
  ['gift_card.partially_redeemed', 'GiftCard'],

  // ── Returns ──────────────────────────────────────────────────────────────
  ['return_authorization.canceled', 'ReturnAuthorization'],
  ['return_item.received', 'ReturnItem'],
  ['return_item.given', 'ReturnItem'],
  ['return_item.canceled', 'ReturnItem'],

  // ── Newsletter ───────────────────────────────────────────────────────────
  ['newsletter_subscriber.subscription_requested', 'NewsletterSubscriber'],
  ['newsletter_subscriber.verified', 'NewsletterSubscriber'],

  // ── Events whose payload is an ad-hoc hash, not a serializer ───────────────
  // The backend emits these with a custom payload (no V3 serializer), so they
  // carry `Record<string, unknown>`. Listed explicitly so they're still part of
  // the typed union and `switch (event.name)` stays exhaustive.
  ['customer.password_reset', 'unknown'],
  ['customer.password_reset_requested', 'unknown'],
  ['invitation.created', 'unknown'],
  ['invitation.accepted', 'unknown'],
  ['invitation.resent', 'unknown'],
]

function knownTypes(): Set<string> {
  return new Set(
    fs
      .readdirSync(TYPES_DIR)
      .filter((f) => f.endsWith('.ts') && f !== 'index.ts')
      .map((f) => f.replace(/\.ts$/, '')),
  )
}

function main() {
  const types = knownTypes()
  const seen = new Set<string>()
  const usedTypes = new Set<string>()

  for (const [name, type] of CATALOG) {
    if (seen.has(name)) throw new Error(`Duplicate webhook event in CATALOG: ${name}`)
    seen.add(name)
    if (type !== 'unknown') {
      if (!types.has(type)) {
        throw new Error(
          `Event "${name}" maps to type "${type}", which has no file in src/types/generated. ` +
            `Fix the CATALOG entry or regenerate types first.`,
        )
      }
      usedTypes.add(type)
    }
  }

  const sortedTypes = [...usedTypes].sort()
  const members = CATALOG.map(
    ([name, type]) =>
      `  | { name: '${name}'; data: ${type === 'unknown' ? 'Record<string, unknown>' : type} }`,
  ).join('\n')

  const out = `// DO NOT MODIFY: generated by scripts/generate-webhook-events.ts
// Run \`pnpm generate:webhook-events\` to regenerate.
//
// The discriminated union of every event Spree can deliver to a webhook
// endpoint. The \`data\` payload type is the Store API V3 serializer output —
// the same shape the REST API returns. Narrow on \`name\` to type \`data\`:
//
//   switch (event.name) {
//     case 'order.completed': event.data // Order
//     case 'product.updated': event.data // Product
//   }
import type {
${sortedTypes.map((t) => `  ${t},`).join('\n')}
} from './types/generated'

/** Discriminated union of every Spree webhook event, keyed by \`name\`. */
export type SpreeWebhookEventData =
${members}

/** Every event name Spree can deliver to a webhook endpoint. */
export type SpreeWebhookEventName = SpreeWebhookEventData['name']

/** Runtime set of every known event name (for filtering/validation). */
export const SPREE_WEBHOOK_EVENT_NAMES = [
${CATALOG.map(([name]) => `  '${name}',`).join('\n')}
] as const
`

  fs.writeFileSync(OUT_FILE, out)
  console.log(
    `Generated ${OUT_FILE} — ${CATALOG.length} events across ${sortedTypes.length} types.`,
  )
}

main()
