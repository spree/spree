import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

const mockClient = {
  auth: {
    login: vi.fn(),
    register: vi.fn(),
    refresh: vi.fn(),
  },
  customer: {
    get: vi.fn(),
    update: vi.fn(),
  },
  cart: {
    associate: vi.fn(),
  },
};

vi.mock('@spree/sdk', () => ({
  createSpreeClient: vi.fn(() => mockClient),
  SpreeError: class SpreeError extends Error {
    public readonly code: string;
    public readonly status: number;
    constructor(response: { error: { code: string; message: string } }, status: number) {
      super(response.error.message);
      this.code = response.error.code;
      this.status = status;
    }
  },
}));

import { login, register, logout, getCustomer, updateCustomer } from '../../src/actions/auth';
import { revalidateTag } from 'next/cache';

describe('auth actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', apiKey: 'pk_test' });
  });

  describe('login', () => {
    it('returns user on success and sets token', async () => {
      const authResult = {
        token: 'jwt_new',
        user: { id: '1', email: 'test@example.com', first_name: 'Test', last_name: 'User' },
      };
      mockCookieStore.get.mockReturnValue(undefined); // no cart token
      mockClient.auth.login.mockResolvedValue(authResult);

      const result = await login('test@example.com', 'password123');
      expect(result.success).toBe(true);
      expect(result.user).toEqual(authResult.user);
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_jwt',
        'jwt_new',
        expect.any(Object)
      );
      expect(revalidateTag).toHaveBeenCalledWith('customer');
    });

    it('associates guest cart after login', async () => {
      const authResult = { token: 'jwt_new', user: { id: '1', email: 'a@b.com' } };
      mockCookieStore.get
        .mockReturnValueOnce({ value: 'guest_cart_token' }); // getCartToken
      mockClient.auth.login.mockResolvedValue(authResult);
      mockClient.cart.associate.mockResolvedValue({});

      await login('a@b.com', 'pass');
      expect(mockClient.cart.associate).toHaveBeenCalledWith({
        token: 'jwt_new',
        orderToken: 'guest_cart_token',
      });
    });

    it('returns error on failure', async () => {
      mockClient.auth.login.mockRejectedValue(new Error('Invalid credentials'));

      const result = await login('bad@email.com', 'wrong');
      expect(result.success).toBe(false);
      expect(result.error).toBe('Invalid credentials');
    });
  });

  describe('logout', () => {
    it('clears access token and invalidates caches', async () => {
      await logout();
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_jwt',
        '',
        expect.objectContaining({ maxAge: -1 })
      );
      expect(revalidateTag).toHaveBeenCalledWith('customer');
      expect(revalidateTag).toHaveBeenCalledWith('cart');
      expect(revalidateTag).toHaveBeenCalledWith('addresses');
      expect(revalidateTag).toHaveBeenCalledWith('credit-cards');
    });
  });

  describe('getCustomer', () => {
    it('returns null when not authenticated', async () => {
      mockCookieStore.get.mockReturnValue(undefined);
      const customer = await getCustomer();
      expect(customer).toBeNull();
    });

    it('returns customer when authenticated', async () => {
      const mockUser = { id: '1', email: 'test@test.com' };
      mockCookieStore.get.mockReturnValue({ value: 'valid_jwt' });
      mockClient.customer.get.mockResolvedValue(mockUser);

      const customer = await getCustomer();
      expect(customer).toEqual(mockUser);
    });
  });
});
