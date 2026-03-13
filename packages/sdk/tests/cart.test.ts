import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { Client } from '../src';

describe('carts', () => {
  let client: Client;
  beforeAll(() => { client = createTestClient(); });
  const opts = { token: 'user-jwt' };

  describe('list', () => {
    it('lists all active carts for authenticated user', async () => {
      const result = await client.carts.list({ token: 'user-jwt' });
      expect(result.data).toHaveLength(1);
      expect(result.data[0].id).toBe('cart_1');
      expect(result.meta.count).toBe(1);
    });
  });

  describe('get', () => {
    it('returns a cart by ID', async () => {
      const result = await client.carts.get('cart_1', opts);

      expect(result.id).toBe('cart_1');
      expect(result.token).toBeDefined();
      expect(result.state).toBeDefined();
      expect(result.checkout_steps).toBeDefined();
    });

    it('works with spreeToken for guest checkout', async () => {
      const result = await client.carts.get('cart_1', { spreeToken: 'guest-token' });
      expect(result).toBeDefined();
    });
  });

  describe('create', () => {
    it('creates a new cart', async () => {
      const result = await client.carts.create();
      expect(result.token).toBe('new-cart-token');
    });
  });

  describe('update', () => {
    it('updates cart info', async () => {
      const result = await client.carts.update(
        'cart_1',
        { email: 'new@example.com' },
        opts
      );
      expect(result.id).toBe('cart_1');
    });
  });

  describe('delete', () => {
    it('deletes a cart by ID', async () => {
      await expect(client.carts.delete('cart_1', opts)).resolves.toBeUndefined();
    });
  });

  describe('associate', () => {
    it('associates guest cart with authenticated user', async () => {
      const result = await client.carts.associate('cart_1', {
        token: 'user-jwt',
        spreeToken: 'guest-token',
      });
      expect(result).toBeDefined();
    });
  });

  describe('complete', () => {
    it('completes the cart and returns an order', async () => {
      const result = await client.carts.complete('cart_1', opts);
      expect(result.id).toBe('or_1');
      expect(result.completed_at).toBeDefined();
    });
  });

  describe('items', () => {
    it('adds an item to the cart', async () => {
      const result = await client.carts.items.create(
        'cart_1',
        { variant_id: 'var_1', quantity: 2 },
        opts
      );
      expect(result.id).toBe('cart_1');
    });

    it('updates a line item', async () => {
      const result = await client.carts.items.update(
        'cart_1',
        'li_1',
        { quantity: 5 },
        opts
      );
      expect(result.id).toBe('cart_1');
    });

    it('removes a line item', async () => {
      const result = await client.carts.items.delete('cart_1', 'li_1', opts);
      expect(result.id).toBe('cart_1');
    });
  });

  describe('couponCodes', () => {
    it('applies a coupon code', async () => {
      const result = await client.carts.couponCodes.apply('cart_1', 'SAVE10', opts);
      expect(result.id).toBe('cart_1');
    });

    it('removes a coupon code by code string', async () => {
      const result = await client.carts.couponCodes.remove('cart_1', 'SAVE10', opts);
      expect(result.id).toBe('cart_1');
    });
  });

  describe('shipments', () => {
    it('lists shipments', async () => {
      const result = await client.carts.shipments.list('cart_1', opts);
      expect(result.data).toBeDefined();
    });

    it('selects a shipping rate', async () => {
      const result = await client.carts.shipments.update(
        'cart_1',
        'ship_1',
        { selected_shipping_rate_id: 'rate_1' },
        opts
      );
      expect(result.id).toBe('cart_1');
    });
  });

  describe('paymentMethods', () => {
    it('lists payment methods', async () => {
      const result = await client.carts.paymentMethods.list('cart_1', opts);
      expect(result.data).toBeDefined();
    });
  });

  describe('storeCredits', () => {
    it('applies store credit', async () => {
      const result = await client.carts.storeCredits.apply('cart_1', 10, opts);
      expect(result.id).toBe('cart_1');
    });

    it('removes store credit', async () => {
      const result = await client.carts.storeCredits.remove('cart_1', opts);
      expect(result.id).toBe('cart_1');
    });
  });
});
