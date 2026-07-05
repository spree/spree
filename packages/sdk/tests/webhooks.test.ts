import { createHmac } from 'node:crypto'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { verifyWebhookSignature, type WebhookEvent } from '../src/webhooks'

function sign(payload: string, secret: string, timestamp: number): string {
  return createHmac('sha256', secret).update(`${timestamp}.${payload}`).digest('hex')
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
