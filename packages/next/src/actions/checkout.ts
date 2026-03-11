'use server';

import { revalidateTag } from 'next/cache';
import type { Cart, Order, Shipment, UpdateCheckoutParams, ListResponse } from '@spree/sdk';
import { getClient } from '../config';
import { getCheckoutOptions } from '../cookies';

/**
 * Get the current checkout state (cart with expanded associations).
 */
export async function getCheckout(): Promise<Cart> {
  const options = await getCheckoutOptions();
  return getClient().cart.get(options);
}

/**
 * Update checkout info (email, addresses, special instructions).
 */
export async function updateCheckout(
  params: UpdateCheckoutParams
): Promise<Cart> {
  const options = await getCheckoutOptions();
  const result = await getClient().checkout.update(params, options);
  revalidateTag('checkout');
  return result;
}

/**
 * Get shipments with shipping rates for the current cart.
 */
export async function getShipments(): Promise<ListResponse<Shipment>> {
  const options = await getCheckoutOptions();
  return getClient().checkout.shipments.list(options);
}

/**
 * Select a shipping rate for a shipment.
 * Returns the updated cart with recalculated totals.
 */
export async function selectShippingRate(
  shipmentId: string,
  shippingRateId: string
): Promise<Cart> {
  const options = await getCheckoutOptions();
  const result = await getClient().checkout.shipments.update(
    shipmentId,
    { selected_shipping_rate_id: shippingRateId },
    options
  );
  revalidateTag('checkout');
  return result;
}

/**
 * Apply a coupon code to the cart.
 */
export async function applyCoupon(
  code: string
): Promise<Cart> {
  const options = await getCheckoutOptions();
  const result = await getClient().cart.couponCodes.apply(code, options);
  revalidateTag('checkout');
  revalidateTag('cart');
  return result;
}

/**
 * Remove a coupon code from the cart.
 */
export async function removeCoupon(
  code: string
): Promise<Cart> {
  const options = await getCheckoutOptions();
  const result = await getClient().cart.couponCodes.remove(code, options);
  revalidateTag('checkout');
  revalidateTag('cart');
  return result;
}

/**
 * Complete the checkout and place the order.
 */
export async function complete(): Promise<Order> {
  const options = await getCheckoutOptions();
  const result = await getClient().checkout.complete(options);
  revalidateTag('checkout');
  revalidateTag('cart');
  return result;
}
