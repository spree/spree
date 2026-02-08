import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from './setup';
import {
  getCartToken,
  setCartToken,
  clearCartToken,
  getAccessToken,
  setAccessToken,
  clearAccessToken,
} from '../src/cookies';

describe('cookies', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('cart token', () => {
    it('reads cart token from cookies', async () => {
      mockCookieStore.get.mockReturnValue({ value: 'cart_abc123' });
      const token = await getCartToken();
      expect(token).toBe('cart_abc123');
      expect(mockCookieStore.get).toHaveBeenCalledWith('_spree_cart_token');
    });

    it('returns undefined when no cart token', async () => {
      mockCookieStore.get.mockReturnValue(undefined);
      const token = await getCartToken();
      expect(token).toBeUndefined();
    });

    it('sets cart token with httpOnly cookie', async () => {
      await setCartToken('cart_new');
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_cart_token',
        'cart_new',
        expect.objectContaining({
          httpOnly: true,
          sameSite: 'lax',
          path: '/',
          maxAge: 60 * 60 * 24 * 30,
        })
      );
    });

    it('clears cart token', async () => {
      await clearCartToken();
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_cart_token',
        '',
        expect.objectContaining({ maxAge: -1 })
      );
    });
  });

  describe('access token', () => {
    it('reads access token from cookies', async () => {
      mockCookieStore.get.mockReturnValue({ value: 'jwt_token_xyz' });
      const token = await getAccessToken();
      expect(token).toBe('jwt_token_xyz');
      expect(mockCookieStore.get).toHaveBeenCalledWith('_spree_jwt');
    });

    it('sets access token with httpOnly cookie', async () => {
      await setAccessToken('jwt_new');
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_jwt',
        'jwt_new',
        expect.objectContaining({
          httpOnly: true,
          sameSite: 'lax',
          path: '/',
          maxAge: 60 * 60 * 24 * 7,
        })
      );
    });

    it('clears access token', async () => {
      await clearAccessToken();
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_jwt',
        '',
        expect.objectContaining({ maxAge: -1 })
      );
    });
  });
});
