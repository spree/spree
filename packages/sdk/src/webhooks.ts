import { createHmac, timingSafeEqual } from 'node:crypto'
import type { SpreeWebhookEventData, SpreeWebhookEventName } from './webhook-events.generated'

export type {
  SpreeWebhookEventData,
  SpreeWebhookEventName,
} from './webhook-events.generated'
export { SPREE_WEBHOOK_EVENT_NAMES } from './webhook-events.generated'

// ─── Headers ───────────────────────────────────────────────────

/** Header names Spree signs webhooks with. */
export const SIGNATURE_HEADER = 'x-spree-webhook-signature'
export const TIMESTAMP_HEADER = 'x-spree-webhook-timestamp'

// ─── Verification ──────────────────────────────────────────────

/**
 * Verifies the HMAC-SHA256 signature of a Spree webhook request.
 *
 * Spree signs webhooks as: HMAC-SHA256(secret, "{timestamp}.{payload}")
 * with headers X-Spree-Webhook-Signature and X-Spree-Webhook-Timestamp.
 *
 * Prefer {@link constructEvent}, which verifies *and* returns the typed event
 * in one call so an unverified payload can never be used by mistake. Reach for
 * this lower-level helper only when you need the boolean (e.g. custom routing).
 *
 * @param payload - Raw request body string
 * @param signature - Value of X-Spree-Webhook-Signature header
 * @param timestamp - Value of X-Spree-Webhook-Timestamp header
 * @param secret - The webhook endpoint's secret key
 * @param toleranceSeconds - Max age of the timestamp in seconds (default: 300 = 5 min)
 *
 * @example
 * ```ts
 * import { verifyWebhookSignature } from '@spree/sdk/webhooks'
 *
 * const isValid = verifyWebhookSignature(
 *   rawBody,
 *   request.headers['x-spree-webhook-signature'],
 *   request.headers['x-spree-webhook-timestamp'],
 *   process.env.SPREE_WEBHOOK_SECRET
 * )
 * ```
 */
export function verifyWebhookSignature(
  payload: string,
  signature: string,
  timestamp: string,
  secret: string,
  toleranceSeconds = 300,
): boolean {
  const ts = Number.parseInt(timestamp, 10)
  if (Number.isNaN(ts)) return false

  const age = Math.abs(Math.floor(Date.now() / 1000) - ts)
  if (age > toleranceSeconds) return false

  const expected = createHmac('sha256', secret).update(`${timestamp}.${payload}`).digest('hex')

  try {
    return timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
  } catch {
    return false
  }
}

// ─── Construct (verify + parse, one call) ──────────────────────

/**
 * Thrown by {@link constructEvent} when a webhook can't be trusted — bad or
 * missing signature, a timestamp outside the tolerance window, or a body that
 * isn't valid JSON. Catch it to return a 400 from your endpoint.
 */
export type WebhookVerificationErrorCode =
  | 'missing_headers'
  | 'invalid_signature'
  | 'invalid_payload'

export class WebhookVerificationError extends Error {
  readonly code: WebhookVerificationErrorCode

  constructor(message: string, code: WebhookVerificationErrorCode) {
    super(message)
    this.name = 'WebhookVerificationError'
    this.code = code
  }
}

/**
 * Headers as supplied by web frameworks. Accepts a plain object (Express,
 * Next.js pages) or a `Headers` instance (Fetch/Next.js App Router, Hono).
 * Lookups are case-insensitive.
 */
export type WebhookHeaders = Headers | Record<string, string | string[] | undefined>

function getHeader(headers: WebhookHeaders, name: string): string | undefined {
  if (typeof (headers as Headers).get === 'function') {
    return (headers as Headers).get(name) ?? undefined
  }
  const record = headers as Record<string, string | string[] | undefined>
  // `name` is already lower-case; Node frameworks lower-case header keys, but a
  // plain object may carry mixed-case keys (e.g. 'X-Spree-Webhook-Signature'),
  // so match case-insensitively rather than assuming the casing.
  const key = Object.keys(record).find((k) => k.toLowerCase() === name)
  const value = key ? record[key] : undefined
  return Array.isArray(value) ? value[0] : value
}

export interface ConstructEventOptions {
  /** Max age of the signature timestamp in seconds (default: 300 = 5 min). */
  toleranceSeconds?: number
}

/**
 * Verifies a Spree webhook and returns the parsed, fully-typed event in one
 * step. **This is the recommended way to consume a webhook** — because the
 * verified event is the only thing it returns, an unverified payload can never
 * be used by accident.
 *
 * Pass the **raw** request body string (never the JSON-parsed object — parsing
 * and re-stringifying changes the bytes and breaks the signature) and the
 * request headers (a plain object or a `Headers` instance).
 *
 * Narrow on `event.name` to get a typed `event.data`. To type events emitted
 * by your own custom models or extensions, pass them as the `TExtra` type
 * parameter — see {@link SpreeWebhookEvent}:
 * `constructEvent<MyEvents>(body, headers, secret)`.
 *
 * @throws {WebhookVerificationError} if headers are missing, the signature is
 *   invalid or stale, or the body isn't valid JSON.
 *
 * @example Next.js App Router
 * ```ts
 * import { constructEvent, WebhookVerificationError } from '@spree/sdk/webhooks'
 *
 * export async function POST(req: Request) {
 *   const rawBody = await req.text()
 *   try {
 *     const event = constructEvent(rawBody, req.headers, process.env.SPREE_WEBHOOK_SECRET!)
 *     switch (event.name) {
 *       case 'order.completed':
 *         await fulfil(event.data) // event.data is Order
 *         break
 *       case 'product.updated':
 *         await reindex(event.data) // event.data is Product
 *         break
 *     }
 *   } catch (err) {
 *     if (err instanceof WebhookVerificationError) return new Response('bad signature', { status: 400 })
 *     throw err
 *   }
 *   return new Response('ok')
 * }
 * ```
 *
 * @example Express (needs the raw body — mount `express.raw({ type: 'application/json' })`)
 * ```ts
 * app.post('/webhooks/spree', express.raw({ type: 'application/json' }), (req, res) => {
 *   const event = constructEvent(req.body.toString('utf8'), req.headers, secret)
 *   // ...
 *   res.send('ok')
 * })
 * ```
 */
export function constructEvent<TExtra extends CustomWebhookEvent = never>(
  payload: string,
  headers: WebhookHeaders,
  secret: string,
  options: ConstructEventOptions = {},
): SpreeWebhookEvent<TExtra> {
  const signature = getHeader(headers, SIGNATURE_HEADER)
  const timestamp = getHeader(headers, TIMESTAMP_HEADER)

  if (!signature || !timestamp) {
    throw new WebhookVerificationError(
      `Missing webhook signature headers (${SIGNATURE_HEADER}, ${TIMESTAMP_HEADER})`,
      'missing_headers',
    )
  }

  if (!verifyWebhookSignature(payload, signature, timestamp, secret, options.toleranceSeconds)) {
    throw new WebhookVerificationError(
      'Webhook signature verification failed (invalid signature or stale timestamp)',
      'invalid_signature',
    )
  }

  try {
    return JSON.parse(payload) as SpreeWebhookEvent<TExtra>
  } catch {
    throw new WebhookVerificationError('Webhook payload is not valid JSON', 'invalid_payload')
  }
}

// ─── Types ─────────────────────────────────────────────────────

/**
 * Fields common to every Spree webhook envelope, independent of the event.
 */
export interface WebhookEventEnvelope {
  /** Unique event id (`evt_…`). Use it to dedupe retries. */
  id: string
  /** ISO-8601 time the event was created. */
  created_at: string
  metadata: {
    spree_version: string
  }
}

/**
 * Shape a custom event map must satisfy to extend {@link SpreeWebhookEvent} or
 * {@link constructEvent}: a discriminated union of `{ name; data }` members.
 *
 * @example
 * ```ts
 * import type { Subscription } from './my-types'
 *
 * type MyEvents =
 *   | { name: 'subscription.created'; data: Subscription }
 *   | { name: 'subscription.renewed'; data: Subscription }
 * ```
 */
export type CustomWebhookEvent = { name: string; data: unknown }

/**
 * The fully-typed Spree webhook event — a discriminated union over `name`.
 * Narrow on `event.name` and `event.data` is typed to the matching Store API
 * resource (the same shape the REST API returns).
 *
 * Pass `TExtra` to merge in events emitted by your own custom models or
 * extensions, so they narrow with full types alongside the built-in events.
 *
 * This is a *closed* union over known names, which is what makes narrowing
 * work. For an event whose name isn't in the catalog (e.g. from a newer Spree
 * than your installed SDK, or a custom event you didn't pass via `TExtra`),
 * use the open {@link WebhookEvent} type instead, or compare `event.name`
 * against a variable rather than a string literal.
 *
 * @example Built-in events
 * ```ts
 * function handle(event: SpreeWebhookEvent) {
 *   switch (event.name) {
 *     case 'order.completed':
 *       event.data // Order
 *       break
 *     case 'product.back_in_stock':
 *       event.data // Product
 *       break
 *   }
 * }
 * ```
 *
 * @example With custom-model events
 * ```ts
 * type MyEvents = { name: 'subscription.renewed'; data: Subscription }
 *
 * function handle(event: SpreeWebhookEvent<MyEvents>) {
 *   switch (event.name) {
 *     case 'order.completed':      event.data // Order        (built-in)
 *     case 'subscription.renewed': event.data // Subscription (custom)
 *   }
 * }
 * ```
 */
export type SpreeWebhookEvent<TExtra extends CustomWebhookEvent = never> = WebhookEventEnvelope &
  (SpreeWebhookEventData | TExtra)

/**
 * Generic Spree webhook event envelope, for events outside the typed catalog
 * (e.g. events emitted by a custom model/extension).
 *
 * For known events prefer {@link SpreeWebhookEvent}, whose `data` is typed by
 * `name`. The `data` field here defaults to `unknown` — supply a type to shape
 * it: `WebhookEvent<Order>`.
 *
 * @example
 * ```ts
 * import type { WebhookEvent } from '@spree/sdk/webhooks'
 * import type { Order } from '@spree/sdk'
 *
 * type OrderEvent = WebhookEvent<Order>
 * type CustomEvent = WebhookEvent<{ foo: string }>
 * ```
 */
export interface WebhookEvent<T = unknown> extends WebhookEventEnvelope {
  name: SpreeWebhookEventName | (string & {})
  data: T
}
