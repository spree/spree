import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

const mockClient = {
  store: {
    customer: {
      addresses: {
        list: vi.fn(),
        get: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      },
    },
    auth: {
      refresh: vi.fn(),
    },
  },
};

vi.mock('@spree/sdk', () => ({
  createSpreeClient: vi.fn(() => mockClient),
  SpreeError: class SpreeError extends Error {
    public readonly status: number;
    constructor(response: { error: { message: string } }, status: number) {
      super(response.error.message);
      this.status = status;
    }
  },
}));

import {
  listAddresses,
  getAddress,
  createAddress,
  updateAddress,
  deleteAddress,
} from '../../src/actions/addresses';
import { revalidateTag } from 'next/cache';

// Create a JWT that expires far in the future (no proactive refresh)
function makeFutureJwt(): string {
  const payload = { exp: Math.floor(Date.now() / 1000) + 86400 }; // 24h from now
  return `header.${btoa(JSON.stringify(payload))}.signature`;
}

describe('address actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', publishableKey: 'pk_test' });
    // Authenticated user with valid JWT
    mockCookieStore.get.mockReturnValue({ value: makeFutureJwt() });
  });

  describe('listAddresses', () => {
    it('returns addresses list', async () => {
      const mockAddresses = { data: [{ id: '1', firstname: 'John' }] };
      mockClient.store.customer.addresses.list.mockResolvedValue(mockAddresses);

      const result = await listAddresses();
      expect(result).toEqual(mockAddresses);
      expect(mockClient.store.customer.addresses.list).toHaveBeenCalledWith(
        undefined,
        expect.objectContaining({ token: expect.any(String) })
      );
    });
  });

  describe('getAddress', () => {
    it('returns a single address', async () => {
      const mockAddress = { id: '1', firstname: 'John', lastname: 'Doe' };
      mockClient.store.customer.addresses.get.mockResolvedValue(mockAddress);

      const result = await getAddress('1');
      expect(result).toEqual(mockAddress);
      expect(mockClient.store.customer.addresses.get).toHaveBeenCalledWith(
        '1',
        expect.objectContaining({ token: expect.any(String) })
      );
    });
  });

  describe('createAddress', () => {
    it('creates address and revalidates', async () => {
      const params = {
        firstname: 'Jane',
        lastname: 'Doe',
        address1: '456 Oak Ave',
        city: 'LA',
        zipcode: '90001',
        country_iso: 'US',
      };
      const mockAddress = { id: '2', ...params };
      mockClient.store.customer.addresses.create.mockResolvedValue(mockAddress);

      const result = await createAddress(params);
      expect(result).toEqual(mockAddress);
      expect(mockClient.store.customer.addresses.create).toHaveBeenCalledWith(
        params,
        expect.objectContaining({ token: expect.any(String) })
      );
      expect(revalidateTag).toHaveBeenCalledWith('addresses');
    });
  });

  describe('updateAddress', () => {
    it('updates address and revalidates', async () => {
      const params = { firstname: 'Updated' };
      const mockAddress = { id: '1', firstname: 'Updated', lastname: 'Doe' };
      mockClient.store.customer.addresses.update.mockResolvedValue(mockAddress);

      const result = await updateAddress('1', params);
      expect(result).toEqual(mockAddress);
      expect(mockClient.store.customer.addresses.update).toHaveBeenCalledWith(
        '1',
        params,
        expect.objectContaining({ token: expect.any(String) })
      );
      expect(revalidateTag).toHaveBeenCalledWith('addresses');
    });
  });

  describe('deleteAddress', () => {
    it('deletes address and revalidates', async () => {
      mockClient.store.customer.addresses.delete.mockResolvedValue(undefined);

      await deleteAddress('1');
      expect(mockClient.store.customer.addresses.delete).toHaveBeenCalledWith(
        '1',
        expect.objectContaining({ token: expect.any(String) })
      );
      expect(revalidateTag).toHaveBeenCalledWith('addresses');
    });
  });

  describe('when not authenticated', () => {
    it('throws error', async () => {
      mockCookieStore.get.mockReturnValue(undefined);
      await expect(listAddresses()).rejects.toThrow('Not authenticated');
    });
  });
});
