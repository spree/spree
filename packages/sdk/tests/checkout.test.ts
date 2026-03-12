import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { Client } from '../src';

describe('checkout', () => {
  let client: Client;
  beforeAll(() => { client = createTestClient(); });
  const opts = { token: 'user-jwt' };

  describe('update', () => {
    it('updates checkout info', async () => {
      const result = await client.checkout.update(
        { email: 'new@example.com' },
        opts
      );
      expect(result.id).toBe('cart_1');
    });
  });

  describe('complete', () => {
    it('completes the checkout and returns an order', async () => {
      const result = await client.checkout.complete(opts);
      expect(result.id).toBe('or_1');
      expect(result.completed_at).toBeDefined();
    });
  });

  describe('shipments', () => {
    it('lists shipments', async () => {
      const result = await client.checkout.shipments.list(opts);
      expect(result.data).toBeDefined();
    });

    it('selects a shipping rate', async () => {
      const result = await client.checkout.shipments.update(
        'ship_1',
        { selected_shipping_rate_id: 'rate_1' },
        opts
      );
      expect(result.id).toBe('cart_1');
    });
  });

  describe('paymentMethods', () => {
    it('lists payment methods', async () => {
      const result = await client.checkout.paymentMethods.list(opts);
      expect(result.data).toBeDefined();
    });
  });

  describe('storeCredits', () => {
    it('applies store credit', async () => {
      const result = await client.checkout.storeCredits.apply(10, opts);
      expect(result.id).toBe('cart_1');
    });

    it('removes store credit', async () => {
      const result = await client.checkout.storeCredits.remove(opts);
      expect(result.id).toBe('cart_1');
    });
  });
});
