import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

const mockClient = {
  auth: {
    login: vi.fn(),
    refresh: vi.fn(),
  },
  customers: {
    create: vi.fn(),
  },
  customer: {
    get: vi.fn(),
    update: vi.fn(),
  },
  carts: {
    associate: vi.fn(),
  },
};

vi.mock('@spree/sdk', () => ({
  createClient: vi.fn(() => mockClient),
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

function mockCookies(values: Record<string, string | undefined>) {
  mockCookieStore.get.mockImplementation((name: string) => {
    const val = values[name];
    return val ? { value: val } : undefined;
  });
}

describe('auth actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', publishableKey: 'pk_test' });
  });

  describe('login', () => {
    it('returns user on success and sets token', async () => {
      const authResult = {
        token: 'jwt_new',
        user: { id: '1', email: 'test@example.com', first_name: 'Test', last_name: 'User' },
      };
      mockCookies({}); // no cart token
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
      mockCookies({
        '_spree_cart_token': 'guest_cart_token',
        '_spree_cart_token_id': 'cart_1',
      });
      mockClient.auth.login.mockResolvedValue(authResult);
      mockClient.carts.associate.mockResolvedValue({});

      await login('a@b.com', 'pass');
      expect(mockClient.carts.associate).toHaveBeenCalledWith(
        'cart_1',
        {
          token: 'jwt_new',
          spreeToken: 'guest_cart_token',
        }
      );
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

  describe('register', () => {
    it('calls customers.create with all params and sets token', async () => {
      const authResult = {
        token: 'jwt_new',
        user: { id: '1', email: 'new@example.com', first_name: 'John', last_name: 'Doe' },
      };
      mockCookies({}); // no cart token
      mockClient.customers.create.mockResolvedValue(authResult);

      const result = await register({
        email: 'new@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'John',
        last_name: 'Doe',
        phone: '+1234567890',
        accepts_email_marketing: true,
        metadata: { source: 'storefront' },
      });

      expect(result.success).toBe(true);
      expect(result.user).toEqual(authResult.user);
      expect(mockClient.customers.create).toHaveBeenCalledWith({
        email: 'new@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'John',
        last_name: 'Doe',
        phone: '+1234567890',
        accepts_email_marketing: true,
        metadata: { source: 'storefront' },
      });
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_jwt',
        'jwt_new',
        expect.any(Object)
      );
      expect(revalidateTag).toHaveBeenCalledWith('customer');
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });

    it('associates guest cart after registration', async () => {
      const authResult = { token: 'jwt_new', user: { id: '1', email: 'new@example.com' } };
      mockCookies({
        '_spree_cart_token': 'guest_cart_token',
        '_spree_cart_token_id': 'cart_1',
      });
      mockClient.customers.create.mockResolvedValue(authResult);
      mockClient.carts.associate.mockResolvedValue({});

      await register({
        email: 'new@example.com',
        password: 'password123',
        password_confirmation: 'password123',
      });

      expect(mockClient.carts.associate).toHaveBeenCalledWith(
        'cart_1',
        {
          token: 'jwt_new',
          spreeToken: 'guest_cart_token',
        }
      );
    });

    it('returns error on failure', async () => {
      mockClient.customers.create.mockRejectedValue(new Error('Email taken'));

      const result = await register({
        email: 'existing@example.com',
        password: 'password123',
        password_confirmation: 'password123',
      });

      expect(result.success).toBe(false);
      expect(result.error).toBe('Email taken');
    });
  });

  describe('updateCustomer', () => {
    it('calls customer.update with all params', async () => {
      const updatedCustomer = {
        id: '1',
        email: 'test@test.com',
        first_name: 'Updated',
        last_name: 'Name',
        phone: '+1234567890',
        accepts_email_marketing: true,
      };
      mockCookies({ '_spree_jwt': 'valid_jwt' });
      mockClient.customer.update.mockResolvedValue(updatedCustomer);

      const result = await updateCustomer({
        first_name: 'Updated',
        phone: '+1234567890',
        accepts_email_marketing: true,
        metadata: { preferred_contact: 'email' },
      });

      expect(result).toEqual(updatedCustomer);
      expect(mockClient.customer.update).toHaveBeenCalledWith(
        {
          first_name: 'Updated',
          phone: '+1234567890',
          accepts_email_marketing: true,
          metadata: { preferred_contact: 'email' },
        },
        expect.any(Object)
      );
      expect(revalidateTag).toHaveBeenCalledWith('customer');
    });
  });

  describe('getCustomer', () => {
    it('returns null when not authenticated', async () => {
      mockCookies({});
      const customer = await getCustomer();
      expect(customer).toBeNull();
    });

    it('returns customer when authenticated', async () => {
      const mockUser = { id: '1', email: 'test@test.com' };
      mockCookies({ '_spree_jwt': 'valid_jwt' });
      mockClient.customer.get.mockResolvedValue(mockUser);

      const customer = await getCustomer();
      expect(customer).toEqual(mockUser);
    });
  });
});
