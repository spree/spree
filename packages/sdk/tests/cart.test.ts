import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { SpreeClient } from '../src';

describe('cart', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('get', () => {
    it('returns the current cart', async () => {
      const result = await client.store.cart.get({ token: 'user-jwt' });

      expect(result.id).toBe('order_1');
      expect(result.token).toBeDefined();
    });

    it('works with order token for guest checkout', async () => {
      const result = await client.store.cart.get({ orderToken: 'guest-token' });
      expect(result).toBeDefined();
    });
  });

  describe('create', () => {
    it('creates a new cart', async () => {
      const result = await client.store.cart.create();
      expect(result.token).toBe('new-cart-token');
    });
  });

  describe('associate', () => {
    it('associates guest cart with authenticated user', async () => {
      const result = await client.store.cart.associate({
        token: 'user-jwt',
        orderToken: 'guest-token',
      });
      expect(result).toBeDefined();
    });
  });
});
