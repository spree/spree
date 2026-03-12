import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

const mockClient = {
  cart: {
    get: vi.fn(),
    couponCodes: {
      apply: vi.fn(),
      remove: vi.fn(),
    },
  },
  checkout: {
    update: vi.fn(),
    complete: vi.fn(),
    shipments: {
      list: vi.fn(),
      update: vi.fn(),
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

describe('checkout actions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', publishableKey: 'pk_test' });
    // Default: cart token and access token available
    mockCookieStore.get
      .mockReturnValueOnce({ value: 'order_token_123' }) // getCartToken
      .mockReturnValueOnce({ value: 'jwt_token_abc' });  // getAccessToken
  });

  describe('getCheckout', () => {
    it('fetches cart with auth options', async () => {
      const mockCart = { id: '1', number: 'R123', line_items: [{ id: 'li1' }] };
      mockClient.cart.get.mockResolvedValue(mockCart);

      const result = await getCheckout();
      expect(result).toEqual(mockCart);
      expect(mockClient.cart.get).toHaveBeenCalledWith({
        spreeToken: 'order_token_123',
        token: 'jwt_token_abc',
      });
    });
  });

  describe('updateCheckout', () => {
    it('updates checkout and revalidates', async () => {
      const mockCart = { id: '1', number: 'R123' };
      const params = {
        email: 'test@example.com',
        ship_address: { firstname: 'John', lastname: 'Doe', address1: '123 Main St', city: 'NY', zipcode: '10001', country_iso: 'US' },
      };
      mockClient.checkout.update.mockResolvedValue(mockCart);

      const result = await updateCheckout(params);
      expect(result).toEqual(mockCart);
      expect(mockClient.checkout.update).toHaveBeenCalledWith(
        params,
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('getShipments', () => {
    it('returns shipments for the cart', async () => {
      const mockShipments = { data: [{ id: 's1', shipping_rates: [] }] };
      mockClient.checkout.shipments.list.mockResolvedValue(mockShipments);

      const result = await getShipments();
      expect(result).toEqual(mockShipments);
      expect(mockClient.checkout.shipments.list).toHaveBeenCalledWith(
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
    });
  });

  describe('selectShippingRate', () => {
    it('selects shipping rate and revalidates checkout', async () => {
      const mockCart = { id: '1', number: 'R123', ship_total: '10.0' };
      mockClient.checkout.shipments.update.mockResolvedValue(mockCart);

      const result = await selectShippingRate('s1', 'sr1');
      expect(result).toEqual(mockCart);
      expect(mockClient.checkout.shipments.update).toHaveBeenCalledWith(
        's1',
        { selected_shipping_rate_id: 'sr1' },
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('applyCoupon', () => {
    it('applies coupon and revalidates checkout and cart', async () => {
      const mockCart = { id: '1', promo_total: -10 };
      mockClient.cart.couponCodes.apply.mockResolvedValue(mockCart);

      const result = await applyCoupon('SAVE10');
      expect(result).toEqual(mockCart);
      expect(mockClient.cart.couponCodes.apply).toHaveBeenCalledWith(
        'SAVE10',
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('removeCoupon', () => {
    it('removes coupon and revalidates checkout and cart', async () => {
      const mockCart = { id: '1', promo_total: 0 };
      mockClient.cart.couponCodes.remove.mockResolvedValue(mockCart);

      const result = await removeCoupon('SAVE10');
      expect(result).toEqual(mockCart);
      expect(mockClient.cart.couponCodes.remove).toHaveBeenCalledWith(
        'SAVE10',
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('complete', () => {
    it('completes checkout and revalidates checkout and cart', async () => {
      const mockOrder = { id: '1', state: 'complete' };
      mockClient.checkout.complete.mockResolvedValue(mockOrder);

      const result = await complete();
      expect(result).toEqual(mockOrder);
      expect(mockClient.checkout.complete).toHaveBeenCalledWith(
        { spreeToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });
});
