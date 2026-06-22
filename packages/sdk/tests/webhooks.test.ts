import { createHmac } from 'node:crypto'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  constructEvent,
  SIGNATURE_HEADER,
  TIMESTAMP_HEADER,
  verifyWebhookSignature,
  type WebhookEvent,
  WebhookVerificationError,
} from '../src/webhooks'

function sign(payload: string, secret: string, timestamp: number): string {
  return createHmac('sha256', secret).update(`${timestamp}.${payload}`).digest('hex')
}

function signedHeaders(payload: string, secret: string, timestamp: number) {
  return {
    [SIGNATURE_HEADER]: sign(payload, secret, timestamp),
    [TIMESTAMP_HEADER]: String(timestamp),
  }
}

describe('verifyWebhookSignature', () => {
  const secret = 'test_secret_key_abc123'
  const payload = '{"id":"evt_123","name":"order.completed","data":{}}'

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
    const tampered = payload.replace('order.completed', 'order.canceled')

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
      name: 'order.completed',
      created_at: '2026-01-15T12:00:00Z',
      data: { number: 'R123456', email: 'test@example.com' },
      metadata: { spree_version: '5.4.0' },
    }

    expect(event.data.number).toBe('R123456')
    expect(event.data.email).toBe('test@example.com')
    expect(event.name).toBe('order.completed')
  })

  it('defaults data to unknown', () => {
    const event: WebhookEvent = {
      id: 'evt_456',
      name: 'custom.event',
      created_at: '2026-01-15T12:00:00Z',
      data: { anything: 'goes' },
      metadata: { spree_version: '5.4.0' },
    }

    expect(event.id).toBe('evt_456')
  })
})

describe('constructEvent', () => {
  const secret = 'test_secret_key_abc123'
  const event = {
    id: 'evt_123',
    name: 'order.completed',
    created_at: '2026-01-15T12:00:00Z',
    data: { id: 'ord_x8k2', number: 'R123456' },
    metadata: { spree_version: '5.5.0' },
  }
  const payload = JSON.stringify(event)

  beforeEach(() => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-01-15T12:00:00Z'))
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('verifies and returns the parsed event from a plain headers object', () => {
    const timestamp = Math.floor(Date.now() / 1000)
    const result = constructEvent(payload, signedHeaders(payload, secret, timestamp), secret)

    expect(result.name).toBe('order.completed')
    expect(result.data).toEqual(event.data)
    expect(result.id).toBe('evt_123')
  })

  it('accepts a Headers instance (Fetch / App Router)', () => {
    const timestamp = Math.floor(Date.now() / 1000)
    const headers = new Headers(signedHeaders(payload, secret, timestamp))
    const result = constructEvent(payload, headers, secret)

    expect(result.name).toBe('order.completed')
  })

  it('reads headers case-insensitively', () => {
    const timestamp = Math.floor(Date.now() / 1000)
    const result = constructEvent(
      payload,
      {
        'X-Spree-Webhook-Signature': sign(payload, secret, timestamp),
        'X-Spree-Webhook-Timestamp': String(timestamp),
      },
      secret,
    )

    expect(result.name).toBe('order.completed')
  })

  it('throws missing_headers when signature headers are absent', () => {
    try {
      constructEvent(payload, {}, secret)
      expect.unreachable()
    } catch (err) {
      expect(err).toBeInstanceOf(WebhookVerificationError)
      expect((err as WebhookVerificationError).code).toBe('missing_headers')
    }
  })

  it('throws invalid_signature on a bad signature', () => {
    const timestamp = Math.floor(Date.now() / 1000)
    try {
      constructEvent(
        payload,
        { [SIGNATURE_HEADER]: 'nope', [TIMESTAMP_HEADER]: String(timestamp) },
        secret,
      )
      expect.unreachable()
    } catch (err) {
      expect(err).toBeInstanceOf(WebhookVerificationError)
      expect((err as WebhookVerificationError).code).toBe('invalid_signature')
    }
  })

  it('throws invalid_signature on a stale timestamp', () => {
    const old = Math.floor(Date.now() / 1000) - 600
    expect(() => constructEvent(payload, signedHeaders(payload, secret, old), secret)).toThrow(
      WebhookVerificationError,
    )
  })

  it('throws invalid_payload when the body is not valid JSON', () => {
    const badBody = 'not json'
    const timestamp = Math.floor(Date.now() / 1000)
    try {
      constructEvent(badBody, signedHeaders(badBody, secret, timestamp), secret)
      expect.unreachable()
    } catch (err) {
      expect((err as WebhookVerificationError).code).toBe('invalid_payload')
    }
  })

  it('narrows data after switching on the event name', () => {
    const timestamp = Math.floor(Date.now() / 1000)
    const result = constructEvent(payload, signedHeaders(payload, secret, timestamp), secret)

    // Type-level narrowing is asserted in webhooks.test-d.ts; here we only
    // confirm the runtime shape flows through `constructEvent`.
    if (result.name === 'order.completed') {
      expect(result.data.number).toBe('R123456')
    } else {
      expect.unreachable()
    }
  })
})

describe('SpreeWebhookEvent custom events (A)', () => {
  interface Subscription {
    id: string
    plan: string
  }

  type MyEvents =
    | { name: 'subscription.created'; data: Subscription }
    | { name: 'subscription.renewed'; data: Subscription }

  it('constructEvent<TExtra> returns the merged union', () => {
    const secret = 'test_secret_key_abc123'
    const payload = JSON.stringify({
      id: 'evt_sub',
      name: 'subscription.created',
      created_at: '2026-01-15T12:00:00Z',
      data: { id: 'sub_1', plan: 'pro' },
      metadata: { spree_version: '5.5.0' },
    })
    const timestamp = Math.floor(new Date('2026-01-15T12:00:00Z').getTime() / 1000)
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-01-15T12:00:00Z'))

    const event = constructEvent<MyEvents>(
      payload,
      signedHeaders(payload, secret, timestamp),
      secret,
    )
    if (event.name === 'subscription.created') {
      expect(event.data.plan).toBe('pro')
    } else {
      expect.unreachable()
    }

    vi.useRealTimers()
  })
})
