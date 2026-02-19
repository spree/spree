import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { SpreeClient } from '../src';

describe('orders', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });
  const opts = { token: 'user-jwt' };

  describe('get', () => {
    it('returns an order by number', async () => {
      const result = await client.store.orders.get('R123456', undefined, opts);
      expect(result.number).toBe('R123456');
    });
  });

  describe('update', () => {
    it('updates order attributes', async () => {
      const result = await client.store.orders.update(
        'order_1',
        { email: 'new@example.com' },
        opts
      );
      expect(result).toBeDefined();
    });
  });

  describe('checkout flow', () => {
    it('advances to next step', async () => {
      const result = await client.store.orders.next('order_1', opts);
      expect(result.state).toBe('address');
    });

    it('advances through all steps', async () => {
      const result = await client.store.orders.advance('order_1', opts);
      expect(result.state).toBe('complete');
    });

    it('completes the order', async () => {
      const result = await client.store.orders.complete('order_1', opts);
      expect(result.state).toBe('complete');
    });
  });

  describe('lineItems', () => {
    it('creates a line item', async () => {
      const result = await client.store.orders.lineItems.create(
        'order_1',
        { variant_id: 'var_1', quantity: 2 },
        opts
      );
      expect(result.quantity).toBe(2);
    });

    it('updates a line item', async () => {
      const result = await client.store.orders.lineItems.update(
        'order_1',
        'li_1',
        { quantity: 5 },
        opts
      );
      expect(result.quantity).toBe(5);
    });

    it('deletes a line item', async () => {
      await expect(
        client.store.orders.lineItems.delete('order_1', 'li_1', opts)
      ).resolves.toBeUndefined();
    });
  });

  describe('couponCodes', () => {
    it('applies a coupon code', async () => {
      const result = await client.store.orders.couponCodes.apply(
        'order_1',
        'SAVE10',
        opts
      );
      expect(result).toBeDefined();
    });

    it('removes a coupon code', async () => {
      const result = await client.store.orders.couponCodes.remove(
        'order_1',
        'promo_1',
        opts
      );
      expect(result).toBeDefined();
    });
  });

  describe('shipments', () => {
    it('lists shipments', async () => {
      const result = await client.store.orders.shipments.list('order_1', opts);
      expect(result.data).toBeDefined();
    });

    it('updates a shipment', async () => {
      const result = await client.store.orders.shipments.update(
        'order_1',
        'ship_1',
        { selected_shipping_rate_id: 'rate_1' },
        opts
      );
      expect(result).toBeDefined();
    });
  });

  describe('storeCredits', () => {
    it('adds store credit', async () => {
      const result = await client.store.orders.addStoreCredit('order_1', 10, opts);
      expect(result).toBeDefined();
    });

    it('removes store credit', async () => {
      const result = await client.store.orders.removeStoreCredit('order_1', opts);
      expect(result).toBeDefined();
    });
  });
});
