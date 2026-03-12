import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { Client } from '../src';

describe('carts', () => {
  let client: Client;
  beforeAll(() => { client = createTestClient(); });

  describe('list', () => {
    it('lists all active carts for authenticated user', async () => {
      const result = await client.carts.list({ token: 'user-jwt' });
      expect(result.data).toHaveLength(1);
      expect(result.data[0].id).toBe('cart_1');
      expect(result.meta.count).toBe(1);
    });
  });
});

describe('cart', () => {
  let client: Client;
  beforeAll(() => { client = createTestClient(); });
  const opts = { token: 'user-jwt' };

  describe('get', () => {
    it('returns the current cart', async () => {
      const result = await client.cart.get({ token: 'user-jwt' });

      expect(result.id).toBe('cart_1');
      expect(result.token).toBeDefined();
      expect(result.state).toBeDefined();
      expect(result.checkout_steps).toBeDefined();
    });

    it('works with order token for guest checkout', async () => {
      const result = await client.cart.get({ spreeToken: 'guest-token' });
      expect(result).toBeDefined();
    });
  });

  describe('create', () => {
    it('creates a new cart', async () => {
      const result = await client.cart.create();
      expect(result.token).toBe('new-cart-token');
    });
  });

  describe('delete', () => {
    it('deletes the current cart', async () => {
      await expect(client.cart.delete(opts)).resolves.toBeUndefined();
    });
  });

  describe('associate', () => {
    it('associates guest cart with authenticated user', async () => {
      const result = await client.cart.associate({
        token: 'user-jwt',
        spreeToken: 'guest-token',
      });
      expect(result).toBeDefined();
    });
  });

  describe('items', () => {
    it('adds an item to the cart', async () => {
      const result = await client.cart.items.create(
        { variant_id: 'var_1', quantity: 2 },
        opts
      );
      expect(result.id).toBe('cart_1');
    });

    it('updates a line item', async () => {
      const result = await client.cart.items.update(
        'li_1',
        { quantity: 5 },
        opts
      );
      expect(result.id).toBe('cart_1');
    });

    it('removes a line item', async () => {
      const result = await client.cart.items.delete('li_1', opts);
      expect(result.id).toBe('cart_1');
    });
  });

  describe('couponCodes', () => {
    it('applies a coupon code', async () => {
      const result = await client.cart.couponCodes.apply('SAVE10', opts);
      expect(result.id).toBe('cart_1');
    });

    it('removes a coupon code by code string', async () => {
      const result = await client.cart.couponCodes.remove('SAVE10', opts);
      expect(result.id).toBe('cart_1');
    });
  });
});
