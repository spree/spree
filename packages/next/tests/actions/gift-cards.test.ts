import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

const mockClient = {
  store: {
    customer: {
      giftCards: {
        list: vi.fn(),
        get: vi.fn(),
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

import { listGiftCards, getGiftCard } from '../../src/actions/gift-cards';

// Create a JWT that expires far in the future
function makeFutureJwt(): string {
  const payload = { exp: Math.floor(Date.now() / 1000) + 86400 };
  return `header.${btoa(JSON.stringify(payload))}.signature`;
}

describe('gift card actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', publishableKey: 'pk_test' });
    mockCookieStore.get.mockReturnValue({ value: makeFutureJwt() });
  });

  describe('listGiftCards', () => {
    it('returns gift cards list', async () => {
      const mockCards = { data: [{ id: '1', code: 'GIFT100', balance: 100 }] };
      mockClient.store.customer.giftCards.list.mockResolvedValue(mockCards);

      const result = await listGiftCards();
      expect(result).toEqual(mockCards);
      expect(mockClient.store.customer.giftCards.list).toHaveBeenCalledWith(
        undefined,
        expect.objectContaining({ token: expect.any(String) })
      );
    });
  });

  describe('getGiftCard', () => {
    it('returns a single gift card', async () => {
      const mockCard = { id: '1', code: 'GIFT100', balance: 100 };
      mockClient.store.customer.giftCards.get.mockResolvedValue(mockCard);

      const result = await getGiftCard('1');
      expect(result).toEqual(mockCard);
      expect(mockClient.store.customer.giftCards.get).toHaveBeenCalledWith(
        '1',
        expect.objectContaining({ token: expect.any(String) })
      );
    });
  });

  describe('when not authenticated', () => {
    it('throws error', async () => {
      mockCookieStore.get.mockReturnValue(undefined);
      await expect(listGiftCards()).rejects.toThrow('Not authenticated');
    });
  });
});
