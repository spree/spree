import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

// Mock the SDK client
const mockClient = {
  cart: {
    get: vi.fn(),
    create: vi.fn(),
    associate: vi.fn(),
  },
  orders: {
    lineItems: {
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
  },
};

vi.mock('@spree/sdk', () => ({
  createSpreeClient: vi.fn(() => mockClient),
}));

import { getCart, getOrCreateCart, addItem, removeItem, clearCart, associateCart } from '../../src/actions/cart';
import { revalidateTag } from 'next/cache';

describe('cart actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', apiKey: 'pk_test' });
  });

  describe('getCart', () => {
    it('returns null when no tokens exist', async () => {
      mockCookieStore.get.mockReturnValue(undefined);
      const cart = await getCart();
      expect(cart).toBeNull();
    });

    it('returns cart when order token exists', async () => {
      const mockCart = { id: '1', token: 'order_abc', line_items: [] };
      mockCookieStore.get.mockReturnValue({ value: 'order_abc' });
      mockClient.cart.get.mockResolvedValue(mockCart);

      const cart = await getCart();
      expect(cart).toEqual(mockCart);
      expect(mockClient.cart.get).toHaveBeenCalledWith(
        expect.objectContaining({ orderToken: 'order_abc' })
      );
    });

    it('returns null when cart fetch fails', async () => {
      mockCookieStore.get.mockReturnValue({ value: 'bad_token' });
      mockClient.cart.get.mockRejectedValue(new Error('Not found'));

      const cart = await getCart();
      expect(cart).toBeNull();
    });
  });

  describe('getOrCreateCart', () => {
    it('returns existing cart if available', async () => {
      const mockCart = { id: '1', token: 'existing', line_items: [] };
      mockCookieStore.get.mockReturnValue({ value: 'existing' });
      mockClient.cart.get.mockResolvedValue(mockCart);

      const cart = await getOrCreateCart();
      expect(cart).toEqual(mockCart);
      expect(mockClient.cart.create).not.toHaveBeenCalled();
    });

    it('creates new cart when none exists', async () => {
      const newCart = { id: '2', token: 'new_token', line_items: [] };
      mockCookieStore.get.mockReturnValue(undefined);
      mockClient.cart.create.mockResolvedValue(newCart);

      const cart = await getOrCreateCart();
      expect(cart).toEqual(newCart);
      expect(mockClient.cart.create).toHaveBeenCalled();
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_cart_token',
        'new_token',
        expect.any(Object)
      );
    });
  });

  describe('addItem', () => {
    it('adds line item and invalidates cache', async () => {
      const mockCart = { id: '1', token: 'cart_token', line_items: [] };
      const mockLineItem = { id: 'li_1', quantity: 2, variant_id: 'v1' };
      mockCookieStore.get.mockReturnValue({ value: 'cart_token' });
      mockClient.cart.get.mockResolvedValue(mockCart);
      mockClient.orders.lineItems.create.mockResolvedValue(mockLineItem);

      const result = await addItem('v1', 2);
      expect(result).toEqual(mockLineItem);
      expect(mockClient.orders.lineItems.create).toHaveBeenCalledWith(
        '1',
        { variant_id: 'v1', quantity: 2 },
        expect.objectContaining({ orderToken: 'cart_token' })
      );
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('removeItem', () => {
    it('deletes line item and invalidates cache', async () => {
      const mockCart = { id: '1', token: 'cart_token' };
      mockCookieStore.get.mockReturnValue({ value: 'cart_token' });
      mockClient.cart.get.mockResolvedValue(mockCart);
      mockClient.orders.lineItems.delete.mockResolvedValue(undefined);

      await removeItem('li_1');
      expect(mockClient.orders.lineItems.delete).toHaveBeenCalledWith(
        '1',
        'li_1',
        expect.objectContaining({ orderToken: 'cart_token' })
      );
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('clearCart', () => {
    it('clears cart cookie and invalidates cache', async () => {
      await clearCart();
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_cart_token',
        '',
        expect.objectContaining({ maxAge: -1 })
      );
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('associateCart', () => {
    it('returns null when no cart token', async () => {
      mockCookieStore.get.mockReturnValue(undefined);
      const result = await associateCart();
      expect(result).toBeNull();
    });

    it('associates cart when both tokens exist', async () => {
      const mockCart = { id: '1', token: 'cart_token' };
      // First call returns cart token, second returns access token
      mockCookieStore.get
        .mockReturnValueOnce({ value: 'cart_token' })
        .mockReturnValueOnce({ value: 'jwt_token' });
      mockClient.cart.associate.mockResolvedValue(mockCart);

      const result = await associateCart();
      expect(result).toEqual(mockCart);
      expect(mockClient.cart.associate).toHaveBeenCalledWith({
        orderToken: 'cart_token',
        token: 'jwt_token',
      });
    });
  });
});
