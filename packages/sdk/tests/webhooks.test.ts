import { createHmac } from 'node:crypto'
import { afterEach, beforeEach, describe, expect, expectTypeOf, it, vi } from 'vitest'
import type { Order, PasswordResetRequestedEvent } from '../src/types/generated'
import {
  constructWebhookEvent,
  verifyWebhookSignature,
  type WebhookEvent,
  WebhookVerificationError,
} from '../src/webhooks'
import { OrderSchema, PasswordResetRequestedEventSchema, webhookEventSchemas } from '../src/zod'

function sign(payload: string, secret: string, timestamp: number): string {
  return createHmac('sha256', secret).update(`${timestamp}.${payload}`).digest('hex')
}

describe('verifyWebhookSignature', () => {
  const secret = 'test_secret_key_abc123'
  const payload = '{"id":"evt_123","name":"order.placed","data":{}}'

  beforeEach(() => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-01-15T12:00:00Z'))
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('accepts a valid signature', () => {
    const timestamp = Math.floor(Date.now() / 1000)
    const signature = sign(payload, secret, timestamp)

    expect(verifyWebhookSignature(payload, signature, String(timestamp), secret)).toBe(true)
  })

  it('rejects an invalid signature', () => {
    const timestamp = Math.floor(Date.now() / 1000)

    expect(verifyWebhookSignature(payload, 'invalid_signature', String(timestamp), secret)).toBe(
      false,
    )
  })

  it('rejects a wrong secret', () => {
    const timestamp = Math.floor(Date.now() / 1000)
    const signature = sign(payload, 'wrong_secret', timestamp)

    expect(verifyWebhookSignature(payload, signature, String(timestamp), secret)).toBe(false)
  })

  it('rejects a tampered payload', () => {
    const timestamp = Math.floor(Date.now() / 1000)
    const signature = sign(payload, secret, timestamp)
    const tampered = payload.replace('order.placed', 'order.canceled')

    expect(verifyWebhookSignature(tampered, signature, String(timestamp), secret)).toBe(false)
  })

  it('rejects a timestamp older than tolerance', () => {
    const oldTimestamp = Math.floor(Date.now() / 1000) - 600 // 10 minutes ago
    const signature = sign(payload, secret, oldTimestamp)

    expect(verifyWebhookSignature(payload, signature, String(oldTimestamp), secret)).toBe(false)
  })

  it('accepts a timestamp within tolerance', () => {
    const recentTimestamp = Math.floor(Date.now() / 1000) - 200 // 200 seconds ago
    const signature = sign(payload, secret, recentTimestamp)

    expect(verifyWebhookSignature(payload, signature, String(recentTimestamp), secret)).toBe(true)
  })

  it('accepts a custom tolerance', () => {
    const oldTimestamp = Math.floor(Date.now() / 1000) - 600 // 10 minutes ago
    const signature = sign(payload, secret, oldTimestamp)

    // Default 300s tolerance rejects it
    expect(verifyWebhookSignature(payload, signature, String(oldTimestamp), secret, 300)).toBe(
      false,
    )
    // Custom 900s tolerance accepts it
    expect(verifyWebhookSignature(payload, signature, String(oldTimestamp), secret, 900)).toBe(true)
  })

  it('rejects a non-numeric timestamp', () => {
    const signature = sign(payload, secret, 0)

    expect(verifyWebhookSignature(payload, signature, 'not-a-number', secret)).toBe(false)
  })

  it('rejects mismatched signature lengths', () => {
    const timestamp = Math.floor(Date.now() / 1000)

    expect(verifyWebhookSignature(payload, 'short', String(timestamp), secret)).toBe(false)
  })
})

describe('WebhookEvent type', () => {
  it('types data field generically', () => {
    interface OrderData {
      number: string
      email: string
    }

    const event: WebhookEvent<OrderData> = {
      id: 'evt_123',
      name: 'order.placed',
      created_at: '2026-01-15T12:00:00Z',
      data: { number: 'R123456', email: 'test@example.com' },
      metadata: { spree_version: '5.4.0' },
    }

    expect(event.data.number).toBe('R123456')
    expect(event.data.email).toBe('test@example.com')
    expect(event.name).toBe('order.placed')
  })

  it('narrows data by event name', () => {
    const event = {
      id: 'evt_456',
      name: 'customer.password_reset_requested',
      created_at: '2026-01-15T12:00:00Z',
      data: { email: 'test@example.com', reset_token: 'token', store_id: 'store_1' },
      metadata: { spree_version: '6.0.0' },
    } as WebhookEvent

    if (event.name === 'customer.password_reset_requested') {
      expectTypeOf(event.data).toEqualTypeOf<PasswordResetRequestedEvent>()
      expect(event.data.reset_token).toBe('token')
    }
  })

  it('narrows up front to the named events', () => {
    expectTypeOf<WebhookEvent<'order.placed'>['data']>().toEqualTypeOf<Order>()
    expectTypeOf<WebhookEvent<'order.placed'>['name']>().toEqualTypeOf<'order.placed'>()
  })
})

describe('constructWebhookEvent', () => {
  const secret = 'test_secret_key_abc123'
  const body = JSON.stringify({
    id: 'evt_789',
    name: 'order.placed',
    created_at: '2026-01-15T12:00:00Z',
    data: { id: 'or_1', number: 'R123' },
    metadata: { spree_version: '6.0.0', notify_customer: true },
  })

  function headersFor(payload: string, signingSecret = secret) {
    const timestamp = Math.floor(Date.now() / 1000)
    return {
      'X-Spree-Webhook-Signature': sign(payload, signingSecret, timestamp),
      'X-Spree-Webhook-Timestamp': String(timestamp),
    }
  }

  it('returns the event of a genuine request', () => {
    const event = constructWebhookEvent(body, headersFor(body), secret)

    expect(event.name).toBe('order.placed')
    expect(event.metadata.notify_customer).toBe(true)
  })

  it('reads a Fetch Headers object', () => {
    const event = constructWebhookEvent(body, new Headers(headersFor(body)), secret)

    expect(event.id).toBe('evt_789')
  })

  it('refuses a request signed with another secret', () => {
    expect(() => constructWebhookEvent(body, headersFor(body, 'wrong_secret'), secret)).toThrow(
      WebhookVerificationError,
    )
  })

  it('refuses a request without signature headers', () => {
    expect(() => constructWebhookEvent(body, {}, secret)).toThrow(
      /Missing X-Spree-Webhook-Signature/,
    )
  })

  it('validates data with the schema for its event, keeping fields the schema does not list', () => {
    const parse = vi.fn((data: unknown) => ({ id: (data as { id: string }).id }))

    const event = constructWebhookEvent(body, headersFor(body), secret, {
      schemas: { 'order.placed': { parse } },
    })

    expect(parse).toHaveBeenCalledWith({ id: 'or_1', number: 'R123' })
    expect(event.data).toEqual({ id: 'or_1', number: 'R123' })
  })

  it('throws when the schema rejects data', () => {
    const parse = () => {
      throw new Error('invalid order')
    }

    expect(() =>
      constructWebhookEvent(body, headersFor(body), secret, {
        schemas: { 'order.placed': { parse } },
      }),
    ).toThrow('invalid order')
  })

  it('declares a schema for every event', () => {
    expect(webhookEventSchemas['order.placed']).toBe(OrderSchema)
    expect(webhookEventSchemas['customer.password_reset_requested']).toBe(
      PasswordResetRequestedEventSchema,
    )
  })
})
