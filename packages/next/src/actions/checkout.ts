'use server';

import { revalidateTag } from 'next/cache';
import type { Cart, Order, Shipment, UpdateCartParams, ListResponse } from '@spree/sdk';
import { getClient } from '../config';
import { getCheckoutOptions, getCartId } from '../cookies';

async function requireCartId(): Promise<string> {
  const cartId = await getCartId();
  if (!cartId) throw new Error('No cart found');
  return cartId;
}

/**
 * Get the current checkout state (cart with expanded associations).
 */
export async function getCheckout(): Promise<Cart> {
  const options = await getCheckoutOptions();
  const cartId = await requireCartId();
  return getClient().carts.get(cartId, options);
}

/**
 * Update cart info (email, addresses, special instructions).
 */
export async function updateCheckout(
  params: UpdateCartParams
): Promise<Cart> {
  const options = await getCheckoutOptions();
  const cartId = await requireCartId();
  const result = await getClient().carts.update(cartId, params, options);
  revalidateTag('checkout');
  return result;
}

/**
 * Get shipments with shipping rates for the current cart.
 */
export async function getShipments(): Promise<ListResponse<Shipment>> {
  const options = await getCheckoutOptions();
  const cartId = await requireCartId();
  return getClient().carts.shipments.list(cartId, options);
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
  const cartId = await requireCartId();
  const result = await getClient().carts.shipments.update(
    cartId,
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
  const cartId = await requireCartId();
  const result = await getClient().carts.couponCodes.apply(cartId, code, options);
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
  const cartId = await requireCartId();
  const result = await getClient().carts.couponCodes.remove(cartId, code, options);
  revalidateTag('checkout');
  revalidateTag('cart');
  return result;
}

/**
 * Complete the checkout and place the order.
 */
export async function complete(): Promise<Order> {
  const options = await getCheckoutOptions();
  const cartId = await requireCartId();
  const result = await getClient().carts.complete(cartId, options);
  revalidateTag('checkout');
  revalidateTag('cart');
  return result;
}
