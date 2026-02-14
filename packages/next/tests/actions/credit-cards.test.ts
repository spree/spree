import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

const mockClient = {
  store: {
    customer: {
      creditCards: {
        list: vi.fn(),
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

import { listCreditCards, deleteCreditCard } from '../../src/actions/credit-cards';
import { revalidateTag } from 'next/cache';

// Create a JWT that expires far in the future
function makeFutureJwt(): string {
  const payload = { exp: Math.floor(Date.now() / 1000) + 86400 };
  return `header.${btoa(JSON.stringify(payload))}.signature`;
}

describe('credit card actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', publishableKey: 'pk_test' });
    mockCookieStore.get.mockReturnValue({ value: makeFutureJwt() });
  });

  describe('listCreditCards', () => {
    it('returns credit cards list', async () => {
      const mockCards = { data: [{ id: '1', last_digits: '4242' }] };
      mockClient.store.customer.creditCards.list.mockResolvedValue(mockCards);

      const result = await listCreditCards();
      expect(result).toEqual(mockCards);
      expect(mockClient.store.customer.creditCards.list).toHaveBeenCalledWith(
        undefined,
        expect.objectContaining({ token: expect.any(String) })
      );
    });
  });

  describe('deleteCreditCard', () => {
    it('deletes card and revalidates', async () => {
      mockClient.store.customer.creditCards.delete.mockResolvedValue(undefined);

      await deleteCreditCard('1');
      expect(mockClient.store.customer.creditCards.delete).toHaveBeenCalledWith(
        '1',
        expect.objectContaining({ token: expect.any(String) })
      );
      expect(revalidateTag).toHaveBeenCalledWith('credit-cards');
    });
  });

  describe('when not authenticated', () => {
    it('throws error', async () => {
      mockCookieStore.get.mockReturnValue(undefined);
      await expect(listCreditCards()).rejects.toThrow('Not authenticated');
    });
  });
});
