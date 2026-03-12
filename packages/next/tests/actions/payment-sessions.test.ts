import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

const mockClient = {
  checkout: {
    paymentSessions: {
      create: vi.fn(),
      get: vi.fn(),
      update: vi.fn(),
      complete: vi.fn(),
    },
  },
};

vi.mock('@spree/sdk', () => ({
  createClient: vi.fn(() => mockClient),
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
      mockClient.checkout.paymentSessions.create.mockResolvedValue(mockSession);

      const result = await createPaymentSession({ payment_method_id: 'pm_1' });
      expect(result).toEqual(mockSession);
      expect(mockClient.checkout.paymentSessions.create).toHaveBeenCalledWith(
        { payment_method_id: 'pm_1' },
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('getPaymentSession', () => {
    it('returns a payment session by ID', async () => {
      const mockSession = { id: 'ps_1', status: 'pending', amount: '99.99' };
      mockClient.checkout.paymentSessions.get.mockResolvedValue(mockSession);

      const result = await getPaymentSession('ps_1');
      expect(result).toEqual(mockSession);
      expect(mockClient.checkout.paymentSessions.get).toHaveBeenCalledWith(
        'ps_1',
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
    });
  });

  describe('updatePaymentSession', () => {
    it('updates a payment session and revalidates checkout', async () => {
      const mockSession = { id: 'ps_1', status: 'pending', amount: '50.00' };
      mockClient.checkout.paymentSessions.update.mockResolvedValue(mockSession);

      const result = await updatePaymentSession('ps_1', { amount: '50.00' });
      expect(result).toEqual(mockSession);
      expect(mockClient.checkout.paymentSessions.update).toHaveBeenCalledWith(
        'ps_1',
        { amount: '50.00' },
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('completePaymentSession', () => {
    it('completes a payment session and revalidates checkout', async () => {
      const mockSession = { id: 'ps_1', status: 'completed' };
      mockClient.checkout.paymentSessions.complete.mockResolvedValue(mockSession);

      const result = await completePaymentSession('ps_1', { session_result: 'success' });
      expect(result).toEqual(mockSession);
      expect(mockClient.checkout.paymentSessions.complete).toHaveBeenCalledWith(
        'ps_1',
        { session_result: 'success' },
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });

    it('completes without params', async () => {
      const mockSession = { id: 'ps_1', status: 'completed' };
      mockClient.checkout.paymentSessions.complete.mockResolvedValue(mockSession);

      const result = await completePaymentSession('ps_1');
      expect(result).toEqual(mockSession);
      expect(mockClient.checkout.paymentSessions.complete).toHaveBeenCalledWith(
        'ps_1',
        undefined,
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
    });
  });
});
