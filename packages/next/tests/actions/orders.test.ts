import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

const mockClient = {
  orders: {
    list: vi.fn(),
    get: vi.fn(),
  },
  auth: {
    refresh: vi.fn(),
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

import { listOrders, getOrder } from '../../src/actions/orders';

// Create a JWT that expires far in the future
function makeFutureJwt(): string {
  const payload = { exp: Math.floor(Date.now() / 1000) + 86400 };
  return `header.${btoa(JSON.stringify(payload))}.signature`;
}

describe('order actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', apiKey: 'pk_test' });
    mockCookieStore.get.mockReturnValue({ value: makeFutureJwt() });
  });

  describe('listOrders', () => {
    it('returns paginated orders', async () => {
      const mockResponse = {
        data: [{ id: '1', number: 'R001' }],
        meta: { total_count: 1, total_pages: 1 },
      };
      mockClient.orders.list.mockResolvedValue(mockResponse);

      const result = await listOrders({ page: 1 });
      expect(result).toEqual(mockResponse);
      expect(mockClient.orders.list).toHaveBeenCalledWith(
        { page: 1 },
        expect.objectContaining({ token: expect.any(String) })
      );
    });

    it('works without params', async () => {
      const mockResponse = { data: [], meta: { total_count: 0, total_pages: 0 } };
      mockClient.orders.list.mockResolvedValue(mockResponse);

      const result = await listOrders();
      expect(result).toEqual(mockResponse);
      expect(mockClient.orders.list).toHaveBeenCalledWith(
        undefined,
        expect.objectContaining({ token: expect.any(String) })
      );
    });
  });

  describe('getOrder', () => {
    it('returns a single order by id', async () => {
      const mockOrder = { id: '1', number: 'R001', state: 'complete' };
      mockClient.orders.get.mockResolvedValue(mockOrder);

      const result = await getOrder('1');
      expect(result).toEqual(mockOrder);
      expect(mockClient.orders.get).toHaveBeenCalledWith(
        '1',
        undefined,
        expect.objectContaining({ token: expect.any(String) })
      );
    });

    it('passes params through', async () => {
      const mockOrder = { id: '1', number: 'R001' };
      mockClient.orders.get.mockResolvedValue(mockOrder);

      const result = await getOrder('R001', { includes: 'line_items' });
      expect(result).toEqual(mockOrder);
      expect(mockClient.orders.get).toHaveBeenCalledWith(
        'R001',
        { includes: 'line_items' },
        expect.objectContaining({ token: expect.any(String) })
      );
    });
  });

  describe('when not authenticated', () => {
    it('throws error', async () => {
      mockCookieStore.get.mockReturnValue(undefined);
      await expect(listOrders()).rejects.toThrow('Not authenticated');
    });
  });
});
