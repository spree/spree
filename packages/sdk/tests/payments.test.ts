import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { SpreeClient } from '../src';

describe('payments', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });
  const opts = { token: 'user-jwt' };

  describe('list', () => {
    it('returns payments for an order', async () => {
      const result = await client.store.orders.payments.list('order_1', opts);
      expect(result.data).toHaveLength(1);
      expect(result.data[0].id).toBe('py_1');
      expect(result.data[0].state).toBe('checkout');
      expect(result.data[0].amount).toBe('19.99');
    });

    it('includes source_type, source_id, and source for credit card payments', async () => {
      const result = await client.store.orders.payments.list('order_1', opts);
      const payment = result.data[0];
      expect(payment.source_type).toBe('credit_card');
      expect(payment.source_id).toBe('card_1');
      expect(payment.source).toBeDefined();
      expect(payment.source!.id).toBe('card_1');
      if (payment.source_type === 'credit_card') {
        const source = payment.source as { cc_type: string; last_digits: string };
        expect(source.cc_type).toBe('visa');
        expect(source.last_digits).toBe('4242');
      }
    });

    it('includes payment_method association', async () => {
      const result = await client.store.orders.payments.list('order_1', opts);
      expect(result.data[0].payment_method.id).toBe('pm_1');
      expect(result.data[0].payment_method.name).toBe('Credit Card');
    });
  });

  describe('get', () => {
    it('returns a payment by ID', async () => {
      const result = await client.store.orders.payments.get('order_1', 'py_1', opts);
      expect(result.id).toBe('py_1');
      expect(result.state).toBe('checkout');
      expect(result.number).toBe('P1234');
      expect(result.payment_method_id).toBe('pm_1');
    });

    it('includes source details', async () => {
      const result = await client.store.orders.payments.get('order_1', 'py_1', opts);
      expect(result.source_type).toBe('credit_card');
      expect(result.source_id).toBe('card_1');
      expect(result.source).toBeDefined();
      expect(result.source!.id).toBe('card_1');
    });
  });
});
