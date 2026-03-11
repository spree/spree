import { describe, it, expect, beforeAll } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from './mocks/server';
import { createTestClient, TEST_BASE_URL } from './helpers';
import { fixtures } from './mocks/handlers';
import type { Client } from '../src';

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`;

describe('customer', () => {
  let client: Client;
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

    it('sends phone, accepts_email_marketing, and metadata', async () => {
      let capturedBody: Record<string, unknown> = {};
      server.use(
        http.patch(`${API_PREFIX}/customer`, async ({ request }) => {
          capturedBody = await request.json() as Record<string, unknown>;
          return HttpResponse.json({ ...fixtures.user, phone: '+1234567890', accepts_email_marketing: true });
        })
      );

      const result = await client.customer.update(
        { phone: '+1234567890', accepts_email_marketing: true, metadata: { source: 'app' } },
        opts
      );

      expect(capturedBody.phone).toBe('+1234567890');
      expect(capturedBody.accepts_email_marketing).toBe(true);
      expect(capturedBody.metadata).toEqual({ source: 'app' });
      expect(result.phone).toBe('+1234567890');
      expect(result.accepts_email_marketing).toBe(true);
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

  describe('orders', () => {
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
