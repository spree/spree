import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

const mockClient = {
  store: {
    orders: {
      paymentSessions: {
        create: vi.fn(),
        get: vi.fn(),
        update: vi.fn(),
        complete: vi.fn(),
      },
    },
  },
};

vi.mock('@spree/sdk', () => ({
  createSpreeClient: vi.fn(() => mockClient),
}));

import {
  createPaymentSession,
  getPaymentSession,
  updatePaymentSession,
  completePaymentSession,
} from '../../src/actions/payment-sessions';
import { revalidateTag } from 'next/cache';

describe('payment session actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', publishableKey: 'pk_test' });
    mockCookieStore.get
      .mockReturnValueOnce({ value: 'order_token_123' })
      .mockReturnValueOnce({ value: 'jwt_token_abc' });
  });

  describe('createPaymentSession', () => {
    it('creates a payment session and revalidates checkout', async () => {
      const mockSession = { id: 'ps_1', status: 'pending', payment_method_id: 'pm_1' };
      mockClient.store.orders.paymentSessions.create.mockResolvedValue(mockSession);

      const result = await createPaymentSession('order_1', { payment_method_id: 'pm_1' });
      expect(result).toEqual(mockSession);
      expect(mockClient.store.orders.paymentSessions.create).toHaveBeenCalledWith(
        'order_1',
        { payment_method_id: 'pm_1' },
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('getPaymentSession', () => {
    it('returns a payment session by ID', async () => {
      const mockSession = { id: 'ps_1', status: 'pending', amount: '99.99' };
      mockClient.store.orders.paymentSessions.get.mockResolvedValue(mockSession);

      const result = await getPaymentSession('order_1', 'ps_1');
      expect(result).toEqual(mockSession);
      expect(mockClient.store.orders.paymentSessions.get).toHaveBeenCalledWith(
        'order_1',
        'ps_1',
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
    });
  });

  describe('updatePaymentSession', () => {
    it('updates a payment session and revalidates checkout', async () => {
      const mockSession = { id: 'ps_1', status: 'pending', amount: '50.00' };
      mockClient.store.orders.paymentSessions.update.mockResolvedValue(mockSession);

      const result = await updatePaymentSession('order_1', 'ps_1', { amount: '50.00' });
      expect(result).toEqual(mockSession);
      expect(mockClient.store.orders.paymentSessions.update).toHaveBeenCalledWith(
        'order_1',
        'ps_1',
        { amount: '50.00' },
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('completePaymentSession', () => {
    it('completes a payment session and revalidates checkout', async () => {
      const mockSession = { id: 'ps_1', status: 'completed' };
      mockClient.store.orders.paymentSessions.complete.mockResolvedValue(mockSession);

      const result = await completePaymentSession('order_1', 'ps_1', { session_result: 'success' });
      expect(result).toEqual(mockSession);
      expect(mockClient.store.orders.paymentSessions.complete).toHaveBeenCalledWith(
        'order_1',
        'ps_1',
        { session_result: 'success' },
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });

    it('completes without params', async () => {
      const mockSession = { id: 'ps_1', status: 'completed' };
      mockClient.store.orders.paymentSessions.complete.mockResolvedValue(mockSession);

      const result = await completePaymentSession('order_1', 'ps_1');
      expect(result).toEqual(mockSession);
      expect(mockClient.store.orders.paymentSessions.complete).toHaveBeenCalledWith(
        'order_1',
        'ps_1',
        undefined,
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
    });
  });
});
