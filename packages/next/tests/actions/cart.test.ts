import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

// Mock the SDK client
const mockClient = {
  carts: {
    get: vi.fn(),
    list: vi.fn(),
    create: vi.fn(),
    associate: vi.fn(),
    items: {
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
    couponCodes: {
      apply: vi.fn(),
      remove: vi.fn(),
    },
  },
};

vi.mock('@spree/sdk', () => ({
  createClient: vi.fn(() => mockClient),
}));

import { getCart, getOrCreateCart, addItem, updateItem, removeItem, clearCart, associateCart } from '../../src/actions/cart';
import { revalidateTag } from 'next/cache';

// Cookie names used by the actions:
// _spree_cart_token      → getCartToken()
// _spree_cart_token_id   → getCartId()
// _spree_jwt             → getAccessToken()

function mockCookies(values: Record<string, string | undefined>) {
  mockCookieStore.get.mockImplementation((name: string) => {
    const val = values[name];
    return val ? { value: val } : undefined;
  });
}

describe('cart actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', publishableKey: 'pk_test' });
  });

  describe('getCart', () => {
    it('returns null when no tokens exist', async () => {
      mockCookies({});
      const cart = await getCart();
      expect(cart).toBeNull();
    });

    it('returns cart when cart ID and token exist', async () => {
      const mockCart = { id: 'cart_1', token: 'order_abc', items: [] };
      mockCookies({
        '_spree_cart_token': 'order_abc',
        '_spree_cart_token_id': 'cart_1',
      });
      mockClient.carts.get.mockResolvedValue(mockCart);

      const cart = await getCart();
      expect(cart).toEqual(mockCart);
      expect(mockClient.carts.get).toHaveBeenCalledWith(
        'cart_1',
        expect.objectContaining({ spreeToken: 'order_abc' })
      );
    });

    it('returns null when cart fetch fails', async () => {
      mockCookies({
        '_spree_cart_token': 'bad_token',
        '_spree_cart_token_id': 'cart_1',
      });
      mockClient.carts.get.mockRejectedValue(new Error('Not found'));

      const cart = await getCart();
      expect(cart).toBeNull();
    });
  });

  describe('getOrCreateCart', () => {
    it('returns existing cart if available', async () => {
      const mockCart = { id: 'cart_1', token: 'existing', items: [] };
      mockCookies({
        '_spree_cart_token': 'existing',
        '_spree_cart_token_id': 'cart_1',
      });
      mockClient.carts.get.mockResolvedValue(mockCart);

      const cart = await getOrCreateCart();
      expect(cart).toEqual(mockCart);
      expect(mockClient.carts.create).not.toHaveBeenCalled();
    });

    it('creates new cart when none exists', async () => {
      const newCart = { id: 'cart_2', token: 'new_token', items: [] };
      mockCookies({});
      mockClient.carts.create.mockResolvedValue(newCart);

      const cart = await getOrCreateCart();
      expect(cart).toEqual(newCart);
      expect(mockClient.carts.create).toHaveBeenCalled();
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_cart_token',
        'new_token',
        expect.any(Object)
      );
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_cart_token_id',
        'cart_2',
        expect.any(Object)
      );
    });
  });

  describe('addItem', () => {
    it('adds item and invalidates cache', async () => {
      const mockCart = { id: 'cart_1', token: 'cart_token', items: [] };
      const updatedCart = { id: 'cart_1', token: 'cart_token', items: [{ id: 'li_1' }] };
      mockCookies({
        '_spree_cart_token': 'cart_token',
        '_spree_cart_token_id': 'cart_1',
      });
      mockClient.carts.get.mockResolvedValue(mockCart);
      mockClient.carts.items.create.mockResolvedValue(updatedCart);

      const result = await addItem('v1', 2);
      expect(result).toEqual(updatedCart);
      expect(mockClient.carts.items.create).toHaveBeenCalledWith(
        'cart_1',
        { variant_id: 'v1', quantity: 2, metadata: undefined },
        expect.objectContaining({ spreeToken: 'cart_token' })
      );
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('updateItem', () => {
    it('updates item and invalidates cache', async () => {
      const updatedCart = { id: 'cart_1', token: 'cart_token', item_count: 3 };
      mockCookies({
        '_spree_cart_token': 'cart_token',
        '_spree_cart_token_id': 'cart_1',
      });
      mockClient.carts.items.update.mockResolvedValue(updatedCart);

      const result = await updateItem('li_1', { quantity: 3 });
      expect(result).toEqual(updatedCart);
      expect(mockClient.carts.items.update).toHaveBeenCalledWith(
        'cart_1',
        'li_1',
        { quantity: 3 },
        expect.objectContaining({ spreeToken: 'cart_token' })
      );
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('removeItem', () => {
    it('removes item and invalidates cache', async () => {
      const updatedCart = { id: 'cart_1', token: 'cart_token', item_count: 0 };
      mockCookies({
        '_spree_cart_token': 'cart_token',
        '_spree_cart_token_id': 'cart_1',
      });
      mockClient.carts.items.delete.mockResolvedValue(updatedCart);

      const result = await removeItem('li_1');
      expect(result).toEqual(updatedCart);
      expect(mockClient.carts.items.delete).toHaveBeenCalledWith(
        'cart_1',
        'li_1',
        expect.objectContaining({ spreeToken: 'cart_token' })
      );
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('clearCart', () => {
    it('clears cart cookies and invalidates cache', async () => {
      await clearCart();
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
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('associateCart', () => {
    it('returns null when no cart ID', async () => {
      mockCookies({});
      const result = await associateCart();
      expect(result).toBeNull();
    });

    it('associates cart when cart ID and JWT exist', async () => {
      const mockCart = { id: 'cart_1', token: 'cart_token' };
      mockCookies({
        '_spree_cart_token': 'cart_token',
        '_spree_cart_token_id': 'cart_1',
        '_spree_jwt': 'jwt_token',
      });
      mockClient.carts.associate.mockResolvedValue(mockCart);

      const result = await associateCart();
      expect(result).toEqual(mockCart);
      expect(mockClient.carts.associate).toHaveBeenCalledWith(
        'cart_1',
        { spreeToken: 'cart_token', token: 'jwt_token' }
      );
    });
  });
});
