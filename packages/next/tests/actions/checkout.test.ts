import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

const mockClient = {
  carts: {
    get: vi.fn(),
    update: vi.fn(),
    complete: vi.fn(),
    shipments: {
      list: vi.fn(),
      update: vi.fn(),
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

import {
  getCheckout,
  updateCheckout,
  getShipments,
  selectShippingRate,
  applyCoupon,
  removeCoupon,
  complete,
} from '../../src/actions/checkout';
import { revalidateTag } from 'next/cache';

function mockCookies(values: Record<string, string | undefined>) {
  mockCookieStore.get.mockImplementation((name: string) => {
    const val = values[name];
    return val ? { value: val } : undefined;
  });
}

describe('checkout actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', publishableKey: 'pk_test' });
    mockCookies({
      '_spree_cart_token': 'order_token_123',
      '_spree_cart_token_id': 'cart_1',
      '_spree_jwt': 'jwt_token_abc',
    });
  });

  describe('getCheckout', () => {
    it('fetches cart with auth options', async () => {
      const mockCart = { id: 'cart_1', number: 'R123', items: [{ id: 'li1' }] };
      mockClient.carts.get.mockResolvedValue(mockCart);

      const result = await getCheckout();
      expect(result).toEqual(mockCart);
      expect(mockClient.carts.get).toHaveBeenCalledWith(
        'cart_1',
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
    });
  });

  describe('updateCheckout', () => {
    it('updates checkout and revalidates', async () => {
      const mockCart = { id: 'cart_1', number: 'R123' };
      const params = {
        email: 'test@example.com',
        ship_address: { firstname: 'John', lastname: 'Doe', address1: '123 Main St', city: 'NY', zipcode: '10001', country_iso: 'US' },
      };
      mockClient.carts.update.mockResolvedValue(mockCart);

      const result = await updateCheckout(params);
      expect(result).toEqual(mockCart);
      expect(mockClient.carts.update).toHaveBeenCalledWith(
        'cart_1',
        params,
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('getShipments', () => {
    it('returns shipments for the cart', async () => {
      const mockShipments = { data: [{ id: 's1', shipping_rates: [] }] };
      mockClient.carts.shipments.list.mockResolvedValue(mockShipments);

      const result = await getShipments();
      expect(result).toEqual(mockShipments);
      expect(mockClient.carts.shipments.list).toHaveBeenCalledWith(
        'cart_1',
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
    });
  });

  describe('selectShippingRate', () => {
    it('selects shipping rate and revalidates checkout', async () => {
      const mockCart = { id: 'cart_1', number: 'R123', ship_total: '10.0' };
      mockClient.carts.shipments.update.mockResolvedValue(mockCart);

      const result = await selectShippingRate('s1', 'sr1');
      expect(result).toEqual(mockCart);
      expect(mockClient.carts.shipments.update).toHaveBeenCalledWith(
        'cart_1',
        's1',
        { selected_shipping_rate_id: 'sr1' },
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('applyCoupon', () => {
    it('applies coupon and revalidates checkout and cart', async () => {
      const mockCart = { id: 'cart_1', promo_total: -10 };
      mockClient.carts.couponCodes.apply.mockResolvedValue(mockCart);

      const result = await applyCoupon('SAVE10');
      expect(result).toEqual(mockCart);
      expect(mockClient.carts.couponCodes.apply).toHaveBeenCalledWith(
        'cart_1',
        'SAVE10',
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('removeCoupon', () => {
    it('removes coupon and revalidates checkout and cart', async () => {
      const mockCart = { id: 'cart_1', promo_total: 0 };
      mockClient.carts.couponCodes.remove.mockResolvedValue(mockCart);

      const result = await removeCoupon('SAVE10');
      expect(result).toEqual(mockCart);
      expect(mockClient.carts.couponCodes.remove).toHaveBeenCalledWith(
        'cart_1',
        'SAVE10',
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('complete', () => {
    it('completes checkout and revalidates', async () => {
      const mockOrder = { id: 'cart_1', state: 'complete' };
      mockClient.carts.complete.mockResolvedValue(mockOrder);

      const result = await complete();
      expect(result).toEqual(mockOrder);
      expect(mockClient.carts.complete).toHaveBeenCalledWith(
        'cart_1',
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });
});
