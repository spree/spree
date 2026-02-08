'use server';

import { revalidateTag } from 'next/cache';
import type { StoreOrder, StoreShipment, AddressParams } from '@spree/sdk';
import { getClient } from '../config';
import { getCartToken, getAccessToken } from '../cookies';

async function getCheckoutOptions() {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  return { orderToken, token };
}

/**
 * Get the current checkout order state.
 * Includes line_items, shipments, and addresses by default.
 */
export async function getCheckout(
  orderId: string
): Promise<StoreOrder> {
  const options = await getCheckoutOptions();
  return getClient().orders.get(
    orderId,
    { includes: 'line_items,shipments,ship_address,bill_address' },
    options
  );
}

/**
 * Update shipping and/or billing addresses on the order.
 */
export async function updateAddresses(
  orderId: string,
  params: {
    email?: string;
    ship_address?: AddressParams;
    bill_address?: AddressParams;
    ship_address_id?: string;
    bill_address_id?: string;
  }
): Promise<StoreOrder> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.update(orderId, params, options);
  revalidateTag('checkout');
  return result;
}

/**
 * Advance the checkout to the next step.
 */
export async function advance(orderId: string): Promise<StoreOrder> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.advance(orderId, options);
  revalidateTag('checkout');
  return result;
}

/**
 * Move the checkout to the next step (alias for advance).
 */
export async function next(orderId: string): Promise<StoreOrder> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.next(orderId, options);
  revalidateTag('checkout');
  return result;
}

/**
 * Get shipments for the order (includes available shipping rates).
 */
export async function getShipments(
  orderId: string
): Promise<{ data: StoreShipment[] }> {
  const options = await getCheckoutOptions();
  return getClient().orders.shipments.list(orderId, options);
}

/**
 * Select a shipping rate for a shipment.
 */
export async function selectShippingRate(
  orderId: string,
  shipmentId: string,
  shippingRateId: string
): Promise<StoreShipment> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.shipments.update(
    orderId,
    shipmentId,
    { selected_shipping_rate_id: shippingRateId },
    options
  );
  revalidateTag('checkout');
  return result;
}

/**
 * Apply a coupon code to the order.
 */
export async function applyCoupon(
  orderId: string,
  code: string
): Promise<StoreOrder> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.couponCodes.apply(orderId, code, options);
  revalidateTag('checkout');
  revalidateTag('cart');
  return result;
}

/**
 * Remove a coupon/promotion from the order.
 */
export async function removeCoupon(
  orderId: string,
  promotionId: string
): Promise<StoreOrder> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.couponCodes.remove(orderId, promotionId, options);
  revalidateTag('checkout');
  revalidateTag('cart');
  return result;
}

/**
 * Complete the checkout and place the order.
 */
export async function complete(orderId: string): Promise<StoreOrder> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.complete(orderId, options);
  revalidateTag('checkout');
  revalidateTag('cart');
  return result;
}
