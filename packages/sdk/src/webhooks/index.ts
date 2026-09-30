import { createHmac, timingSafeEqual } from 'node:crypto'
import type { WebhookEventMap } from './generated/events'

// ─── Verification ──────────────────────────────────────────────

/**
 * Verifies the HMAC-SHA256 signature of a Spree webhook request.
 *
 * Spree signs webhooks as: HMAC-SHA256(secret, "{timestamp}.{payload}")
 * with headers X-Spree-Webhook-Signature and X-Spree-Webhook-Timestamp.
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

// ─── Types ─────────────────────────────────────────────────────

export type { WebhookEventMap, WebhookRecordReference } from './generated/events'

/** The name of every webhook event Spree publishes, plus any an extension declared. */
export type WebhookEventName = Extract<keyof WebhookEventMap, string>

/**
 * Spree webhook event envelope.
 *
 * `data` is the record the event carries, serialized with the same Store API
 * serializers as the REST API. Without a type argument this is a union over
 * every event, so checking `event.name` narrows `event.data`. Pass event names
 * to narrow it up front: `WebhookEvent<'order.placed' | 'order.canceled'>`.
 *
 * Passing a data type instead (`WebhookEvent<Order>`) still works, but is
 * deprecated — it types `data` without checking it matches the event.
 *
 * @example
 * ```ts
 * import type { WebhookEvent } from '@spree/sdk/webhooks'
 *
 * function handle(event: WebhookEvent) {
 *   if (event.name === 'order.placed') {
 *     event.data.number // typed as Order
 *   }
 * }
 * ```
 */
export type WebhookEvent<T = WebhookEventName> = T extends WebhookEventName
  ? WebhookEventEnvelope<T, WebhookEventMap[T]>
  : WebhookEventEnvelope<string, T>

interface WebhookEventEnvelope<Name extends string, Data> {
  id: string
  name: Name
  created_at: string
  data: Data
  metadata: WebhookEventMetadata
}

/** Facts about the event itself, alongside the record in `data`. */
export interface WebhookEventMetadata {
  spree_version: string
  [key: string]: unknown
}

// ─── Construction ──────────────────────────────────────────────

/** Anything with a `parse` method returning the parsed value, such as a Zod schema. */
export interface WebhookDataSchema {
  parse(data: unknown): unknown
}

export interface ConstructWebhookEventOptions {
  /** Max age of the timestamp in seconds (default: 300 = 5 min). */
  toleranceSeconds?: number
  /**
   * Schemas to validate `data` with, keyed by event name — pass
   * `webhookEventSchemas` from `@spree/sdk/zod`. An event without a schema
   * is returned unvalidated.
   */
  schemas?: Partial<Record<string, WebhookDataSchema>>
}

/** Raised by {@link constructWebhookEvent} when a request is not a genuine Spree webhook. */
export class WebhookVerificationError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'WebhookVerificationError'
  }
}

type WebhookHeaders = Headers | Record<string, string | string[] | undefined>

function readHeader(headers: WebhookHeaders, name: string): string | undefined {
  if (typeof (headers as Headers).get === 'function') {
    return (headers as Headers).get(name) ?? undefined
  }

  const record = headers as Record<string, string | string[] | undefined>
  const key = Object.keys(record).find((candidate) => candidate.toLowerCase() === name)
  const value = key ? record[key] : undefined
  return Array.isArray(value) ? value[0] : value
}

/**
 * Verifies a webhook request's signature and returns its typed event.
 *
 * @param rawBody - The request body exactly as received, before any JSON parsing
 * @param headers - The request headers (a Fetch `Headers` or a Node headers object)
 * @param secret - The webhook endpoint's secret key
 * @throws {WebhookVerificationError} when the signature is missing, wrong or expired
 *
 * @example
 * ```ts
 * import { constructWebhookEvent } from '@spree/sdk/webhooks'
 * import { webhookEventSchemas } from '@spree/sdk/zod'
 *
 * const event = constructWebhookEvent(rawBody, request.headers, process.env.SPREE_WEBHOOK_SECRET, {
 *   schemas: webhookEventSchemas,
 * })
 *
 * switch (event.name) {
 *   case 'order.placed':
 *     await fulfil(event.data) // Order
 *     break
 *   case 'customer.password_reset_requested':
 *     await sendResetEmail(event.data.email, event.data.reset_token)
 *     break
 * }
 * ```
 */
export function constructWebhookEvent(
  rawBody: string,
  headers: WebhookHeaders,
  secret: string,
  options: ConstructWebhookEventOptions = {},
): WebhookEvent {
  const signature = readHeader(headers, 'x-spree-webhook-signature')
  const timestamp = readHeader(headers, 'x-spree-webhook-timestamp')

  if (!signature || !timestamp) {
    throw new WebhookVerificationError(
      'Missing X-Spree-Webhook-Signature or X-Spree-Webhook-Timestamp header',
    )
  }
  if (!verifyWebhookSignature(rawBody, signature, timestamp, secret, options.toleranceSeconds)) {
    throw new WebhookVerificationError('Webhook signature is invalid or the timestamp is too old')
  }

  const event = JSON.parse(rawBody) as WebhookEvent
  const schema = options.schemas?.[event.name]
  return schema ? ({ ...event, data: schema.parse(event.data) } as WebhookEvent) : event
}
