import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { Client } from '../src';

describe('orders', () => {
  let client: Client;
  beforeAll(() => { client = createTestClient(); });
  const opts = { token: 'user-jwt' };

  describe('get', () => {
    it('returns an order by prefixed ID', async () => {
      const result = await client.orders.get('or_abc123', undefined, opts);
      expect(result.id).toBe('or_1');
      expect(result.completed_at).toBeDefined();
    });

    it('works with order token for guest access', async () => {
      const result = await client.orders.get('or_abc123', undefined, {
        spreeToken: 'guest-token',
      });
      expect(result).toBeDefined();
    });
  });

  describe('customer.orders', () => {
    it('lists customer orders', async () => {
      const result = await client.customer.orders.list(undefined, opts);
      expect(result.data).toHaveLength(1);
      expect(result.meta.page).toBe(1);
    });

    it('gets a customer order by ID', async () => {
      const result = await client.customer.orders.get('or_abc123', undefined, opts);
      expect(result.id).toBe('or_1');
    });
  });
});
