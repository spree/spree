import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { SpreeClient } from '../src';

describe('cart', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('get', () => {
    it('returns the current cart', async () => {
      const result = await client.cart.get({ token: 'user-jwt' });

      expect(result.id).toBe('order_1');
      expect(result.token).toBeDefined();
    });

    it('works with order token for guest checkout', async () => {
      const result = await client.cart.get({ orderToken: 'guest-token' });
      expect(result).toBeDefined();
    });
  });

  describe('create', () => {
    it('creates a new cart', async () => {
      const result = await client.cart.create();
      expect(result.token).toBeDefined();
    });
  });

  describe('associate', () => {
    it('associates guest cart with authenticated user', async () => {
      const result = await client.cart.associate({
        token: 'user-jwt',
        orderToken: 'guest-token',
      });
      expect(result).toBeDefined();
    });
  });
});
