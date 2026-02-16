import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { SpreeClient } from '../src';

describe('paymentSessions', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });
  const opts = { token: 'user-jwt' };

  describe('create', () => {
    it('creates a payment session', async () => {
      const result = await client.store.orders.paymentSessions.create(
        'order_1',
        { payment_method_id: 'pm_1' },
        opts
      );
      expect(result.id).toBe('ps_1');
      expect(result.status).toBe('pending');
      expect(result.payment_method_id).toBe('pm_1');
      expect(result.order_id).toBe('order_1');
      expect(result.external_data).toHaveProperty('client_secret');
    });

    it('accepts optional amount and external_data', async () => {
      const result = await client.store.orders.paymentSessions.create(
        'order_1',
        { payment_method_id: 'pm_1', amount: '50.00', external_data: { channel: 'Web' } },
        opts
      );
      expect(result.id).toBe('ps_1');
    });
  });

  describe('get', () => {
    it('returns a payment session by ID', async () => {
      const result = await client.store.orders.paymentSessions.get(
        'order_1',
        'ps_1',
        opts
      );
      expect(result.id).toBe('ps_1');
      expect(result.status).toBe('pending');
      expect(result.amount).toBe('99.99');
      expect(result.currency).toBe('USD');
      expect(result.external_id).toBe('bogus_abc123');
    });
  });

  describe('update', () => {
    it('updates a payment session', async () => {
      const result = await client.store.orders.paymentSessions.update(
        'order_1',
        'ps_1',
        { amount: '50.00' },
        opts
      );
      expect(result.id).toBe('ps_1');
      expect(result.amount).toBe('50.00');
    });
  });

  describe('complete', () => {
    it('completes a payment session', async () => {
      const result = await client.store.orders.paymentSessions.complete(
        'order_1',
        'ps_1',
        { session_result: 'success' },
        opts
      );
      expect(result.id).toBe('ps_1');
      expect(result.status).toBe('completed');
    });

    it('completes without params', async () => {
      const result = await client.store.orders.paymentSessions.complete(
        'order_1',
        'ps_1',
        undefined,
        opts
      );
      expect(result.status).toBe('completed');
    });
  });
});
