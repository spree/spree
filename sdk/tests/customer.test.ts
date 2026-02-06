import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { SpreeClient } from '../src';

describe('customer', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });
  const opts = { token: 'user-jwt' };

  describe('get', () => {
    it('returns customer profile', async () => {
      const result = await client.customer.get(opts);
      expect(result.email).toBe('test@example.com');
    });
  });

  describe('update', () => {
    it('updates customer profile', async () => {
      const result = await client.customer.update(
        { first_name: 'Updated' },
        opts
      );
      expect(result.first_name).toBe('Updated');
    });
  });

  describe('addresses', () => {
    it('lists addresses', async () => {
      const result = await client.customer.addresses.list(undefined, opts);
      expect(result.data).toHaveLength(1);
    });

    it('gets an address by ID', async () => {
      const result = await client.customer.addresses.get('addr_1', opts);
      expect(result.city).toBe('New York');
    });

    it('creates an address', async () => {
      const result = await client.customer.addresses.create(
        {
          firstname: 'Test',
          lastname: 'User',
          address1: '123 Main St',
          city: 'New York',
          zipcode: '10001',
          country_iso: 'US',
        },
        opts
      );
      expect(result.id).toBeDefined();
    });

    it('updates an address', async () => {
      const result = await client.customer.addresses.update(
        'addr_1',
        { city: 'Updated City' },
        opts
      );
      expect(result.city).toBe('Updated City');
    });

    it('deletes an address', async () => {
      await expect(
        client.customer.addresses.delete('addr_1', opts)
      ).resolves.toBeUndefined();
    });
  });

  describe('creditCards', () => {
    it('lists credit cards', async () => {
      const result = await client.customer.creditCards.list(undefined, opts);
      expect(result.data).toBeDefined();
    });

    it('gets a credit card', async () => {
      const result = await client.customer.creditCards.get('cc_1', opts);
      expect(result).toBeDefined();
    });

    it('deletes a credit card', async () => {
      await expect(
        client.customer.creditCards.delete('cc_1', opts)
      ).resolves.toBeUndefined();
    });
  });

  describe('giftCards', () => {
    it('lists gift cards', async () => {
      const result = await client.customer.giftCards.list(undefined, opts);
      expect(result.data).toBeDefined();
    });

    it('gets a gift card', async () => {
      const result = await client.customer.giftCards.get('gc_1', opts);
      expect(result).toBeDefined();
    });
  });
});
