import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from '../setup';
import { initSpreeNext, resetClient } from '../../src/config';

const mockClient = {
  store: {
    orders: {
      get: vi.fn(),
      update: vi.fn(),
      advance: vi.fn(),
      next: vi.fn(),
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
  },
};

vi.mock('@spree/sdk', () => ({
  createSpreeClient: vi.fn(() => mockClient),
}));

import {
  getCheckout,
  updateAddresses,
  advance,
  next,
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
    it('fetches order with includes and auth options', async () => {
      const mockOrder = { id: '1', number: 'R123', line_items: [{ id: 'li1' }] };
      mockClient.store.orders.get.mockResolvedValue(mockOrder);

      const result = await getCheckout('1');
      expect(result).toEqual(mockOrder);
      expect(mockClient.store.orders.get).toHaveBeenCalledWith(
        '1',
        { includes: 'line_items,shipments,ship_address,bill_address' },
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
    });
  });

  describe('updateAddresses', () => {
    it('updates order addresses and revalidates checkout', async () => {
      const mockOrder = { id: '1', number: 'R123' };
      const addressParams = {
        email: 'test@example.com',
        ship_address: { firstname: 'John', lastname: 'Doe', address1: '123 Main St', city: 'NY', zipcode: '10001', country_iso: 'US' },
      };
      mockClient.store.orders.update.mockResolvedValue(mockOrder);

      const result = await updateAddresses('1', addressParams);
      expect(result).toEqual(mockOrder);
      expect(mockClient.store.orders.update).toHaveBeenCalledWith(
        '1',
        addressParams,
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('advance', () => {
    it('advances checkout and revalidates', async () => {
      const mockOrder = { id: '1', state: 'delivery' };
      mockClient.store.orders.advance.mockResolvedValue(mockOrder);

      const result = await advance('1');
      expect(result).toEqual(mockOrder);
      expect(mockClient.store.orders.advance).toHaveBeenCalledWith(
        '1',
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('next', () => {
    it('moves checkout to next step and revalidates', async () => {
      const mockOrder = { id: '1', state: 'payment' };
      mockClient.store.orders.next.mockResolvedValue(mockOrder);

      const result = await next('1');
      expect(result).toEqual(mockOrder);
      expect(mockClient.store.orders.next).toHaveBeenCalledWith(
        '1',
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('getShipments', () => {
    it('returns shipments for the order', async () => {
      const mockShipments = { data: [{ id: 's1', shipping_rates: [] }] };
      mockClient.store.orders.shipments.list.mockResolvedValue(mockShipments);

      const result = await getShipments('1');
      expect(result).toEqual(mockShipments);
      expect(mockClient.store.orders.shipments.list).toHaveBeenCalledWith(
        '1',
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
    });
  });

  describe('selectShippingRate', () => {
    it('selects shipping rate and revalidates checkout', async () => {
      const mockOrder = { id: '1', number: 'R123', ship_total: '10.0' };
      mockClient.store.orders.shipments.update.mockResolvedValue(mockOrder);

      const result = await selectShippingRate('1', 's1', 'sr1');
      expect(result).toEqual(mockOrder);
      expect(mockClient.store.orders.shipments.update).toHaveBeenCalledWith(
        '1',
        's1',
        { selected_shipping_rate_id: 'sr1' },
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
    });
  });

  describe('applyCoupon', () => {
    it('applies coupon and revalidates checkout and cart', async () => {
      const mockOrder = { id: '1', promo_total: -10 };
      mockClient.store.orders.couponCodes.apply.mockResolvedValue(mockOrder);

      const result = await applyCoupon('1', 'SAVE10');
      expect(result).toEqual(mockOrder);
      expect(mockClient.store.orders.couponCodes.apply).toHaveBeenCalledWith(
        '1',
        'SAVE10',
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('removeCoupon', () => {
    it('removes coupon and revalidates checkout and cart', async () => {
      const mockOrder = { id: '1', promo_total: 0 };
      mockClient.store.orders.couponCodes.remove.mockResolvedValue(mockOrder);

      const result = await removeCoupon('1', 'promo_1');
      expect(result).toEqual(mockOrder);
      expect(mockClient.store.orders.couponCodes.remove).toHaveBeenCalledWith(
        '1',
        'promo_1',
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });

  describe('complete', () => {
    it('completes checkout and revalidates checkout and cart', async () => {
      const mockOrder = { id: '1', state: 'complete' };
      mockClient.store.orders.complete.mockResolvedValue(mockOrder);

      const result = await complete('1');
      expect(result).toEqual(mockOrder);
      expect(mockClient.store.orders.complete).toHaveBeenCalledWith(
        '1',
        { orderToken: 'order_token_123', token: 'jwt_token_abc' }
      );
      expect(revalidateTag).toHaveBeenCalledWith('checkout');
      expect(revalidateTag).toHaveBeenCalledWith('cart');
    });
  });
});
