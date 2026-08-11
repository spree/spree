import { beforeAll, describe, expect, it } from 'vitest'
import type { Client } from '../src'
import { createTestClient } from './helpers'

describe('customer self-service returns and claims', () => {
  let client: Client
  beforeAll(() => {
    client = createTestClient()
  })

  const opts = { token: 'user-jwt' }

  describe('returns', () => {
    it('lists returns the customer opened on an order', async () => {
      const result = await client.orders.returns.list('or_abc123', undefined, opts)

      expect(result.data).toHaveLength(1)
      expect(result.data[0].number).toBe('RET123456789')
      expect(result.data[0].status).toBe('requested')
    })

    it('fetches a single return', async () => {
      const result = await client.orders.returns.get('or_abc123', 'ret_1', undefined, opts)

      expect(result.id).toBe('ret_1')
    })

    // Against fulfilled units, not line items — a return is of something shipped.
    it('opens a return for fulfilled units', async () => {
      const result = await client.orders.returns.create(
        'or_abc123',
        {
          items: [{ fulfillment_item_id: 'fi_1', quantity: 1 }],
          memo: 'Wrong size',
        },
        opts,
      )

      expect(result.status).toBe('requested')
      expect(result.number).toMatch(/^RET/)
    })

    it('works for a guest holding the order token', async () => {
      const result = await client.orders.returns.list('or_abc123', undefined, {
        spreeToken: 'guest-token',
      })

      expect(result.data).toBeDefined()
    })
  })

  describe('claims', () => {
    it('lists claims on an order', async () => {
      const result = await client.orders.claims.list('or_abc123', undefined, opts)

      expect(result.data).toHaveLength(1)
      expect(result.data[0].reason_id).toBe('clr_1')
    })

    it('fetches a single claim', async () => {
      const result = await client.orders.claims.get('or_abc123', 'claim_1', undefined, opts)

      expect(result.id).toBe('claim_1')
    })

    // Against ordered line items — nothing has to have shipped to report a problem.
    it('files a claim against ordered items', async () => {
      const result = await client.orders.claims.create(
        'or_abc123',
        {
          items: [{ line_item_id: 'li_1', quantity: 1, description: 'Arrived cracked' }],
          reason_id: 'clr_1',
        },
        opts,
      )

      expect(result.status).toBe('open')
      expect(result.number).toMatch(/^CLM/)
    })
  })
})
