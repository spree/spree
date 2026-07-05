import { beforeAll, describe, expect, it } from 'vitest'
import type { Client } from '../src'
import { createTestClient } from './helpers'

describe('payments', () => {
  let client: Client
  beforeAll(() => {
    client = createTestClient()
  })
  const opts = { token: 'user-jwt' }

  describe('create', () => {
    it('creates a payment for a non-session payment method', async () => {
      const result = await client.carts.payments.create(
        'cart_1',
        { payment_method_id: 'pm_2' },
        opts,
      )
      expect(result.id).toBe('py_2')
      expect(result.state).toBe('checkout')
      expect(result.payment_method_id).toBe('pm_2')
      expect(result.source_type).toBeNull()
      expect(result.source).toBeNull()
    })

    it('accepts optional amount', async () => {
      const result = await client.carts.payments.create(
        'cart_1',
        { payment_method_id: 'pm_2', amount: '50.00' },
        opts,
      )
      expect(result.id).toBe('py_2')
    })

    it('includes payment_method association', async () => {
      const result = await client.carts.payments.create(
        'cart_1',
        { payment_method_id: 'pm_2' },
        opts,
      )
      expect(result.payment_method.id).toBe('pm_2')
      expect(result.payment_method.name).toBe('Check')
      expect(result.payment_method.session_required).toBe(false)
    })
  })
})
