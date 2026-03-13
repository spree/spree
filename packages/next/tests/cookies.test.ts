import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from './setup';
import {
  getCartToken,
  getCartId,
  setCartCookies,
  clearCartCookies,
  getAccessToken,
  setAccessToken,
  clearAccessToken,
} from '../src/cookies';

describe('cookies', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('cart cookies', () => {
    it('reads cart token from cookies', async () => {
      mockCookieStore.get.mockReturnValue({ value: 'cart_abc123' });
      const token = await getCartToken();
      expect(token).toBe('cart_abc123');
      expect(mockCookieStore.get).toHaveBeenCalledWith('_spree_cart_token');
    });

    it('reads cart ID from cookies', async () => {
      mockCookieStore.get.mockReturnValue({ value: 'or_xyz' });
      const id = await getCartId();
      expect(id).toBe('or_xyz');
      expect(mockCookieStore.get).toHaveBeenCalledWith('_spree_cart_token_id');
    });

    it('returns undefined when no cart token', async () => {
      mockCookieStore.get.mockReturnValue(undefined);
      const token = await getCartToken();
      expect(token).toBeUndefined();
    });

    it('sets both cart ID and token cookies', async () => {
      await setCartCookies('or_123', 'cart_token_abc');
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_cart_token_id',
        'or_123',
        expect.objectContaining({
          httpOnly: true,
          sameSite: 'lax',
          path: '/',
          maxAge: 60 * 60 * 24 * 30,
        })
      );
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_cart_token',
        'cart_token_abc',
        expect.objectContaining({
          httpOnly: true,
          sameSite: 'lax',
          path: '/',
          maxAge: 60 * 60 * 24 * 30,
        })
      );
    });

    it('sets only cart ID when token is undefined', async () => {
      await setCartCookies('or_123');
      expect(mockCookieStore.set).toHaveBeenCalledTimes(1);
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_cart_token_id',
        'or_123',
        expect.objectContaining({ httpOnly: true })
      );
    });

    it('clears both cart cookies', async () => {
      await clearCartCookies();
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_cart_token',
        '',
        expect.objectContaining({ maxAge: -1 })
      );
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_cart_token_id',
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
