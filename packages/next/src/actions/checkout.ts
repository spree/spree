'use server';

import { revalidateTag } from 'next/cache';
import type { Order, Shipment, UpdateOrderParams } from '@spree/sdk';
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
): Promise<Order> {
  const options = await getCheckoutOptions();
  return getClient().orders.get(
    orderId,
    { expand: ['line_items', 'shipments', 'ship_address', 'bill_address'] },
    options
  );
}

/**
 * Update an order (addresses, email, currency, locale, metadata, etc.).
 */
export async function updateOrder(
  orderId: string,
  params: UpdateOrderParams
): Promise<Order> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.update(orderId, params, options);
  revalidateTag('checkout');
  return result;
}

/**
 * Advance the checkout to the next step.
 */
export async function advance(orderId: string): Promise<Order> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.advance(orderId, options);
  revalidateTag('checkout');
  return result;
}

/**
 * Move the checkout to the next step (alias for advance).
 */
export async function next(orderId: string): Promise<Order> {
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
): Promise<{ data: Shipment[] }> {
  const options = await getCheckoutOptions();
  return getClient().orders.shipments.list(orderId, options);
}

/**
 * Select a shipping rate for a shipment.
 * Returns the updated order with recalculated totals.
 */
export async function selectShippingRate(
  orderId: string,
  shipmentId: string,
  shippingRateId: string
): Promise<Order> {
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
): Promise<Order> {
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
): Promise<Order> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.couponCodes.remove(orderId, promotionId, options);
  revalidateTag('checkout');
  revalidateTag('cart');
  return result;
}

/**
 * Complete the checkout and place the order.
 */
export async function complete(orderId: string): Promise<Order> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.complete(orderId, options);
  revalidateTag('checkout');
  revalidateTag('cart');
  return result;
}
