'use server';

import { revalidateTag } from 'next/cache';
import type { StoreOrder } from '@spree/sdk';
import { getClient } from '../config';
import { getCartToken, setCartToken, clearCartToken, getAccessToken } from '../cookies';

/**
 * Get the current cart. Returns null if no cart exists.
 */
export async function getCart(): Promise<(StoreOrder & { token: string }) | null> {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  if (!orderToken && !token) return null;

  try {
    return await getClient().store.cart.get({ orderToken, token });
  } catch {
    // Cart not found (e.g., order was completed) — clear stale token
    if (orderToken) {
      await clearCartToken();
    }
    return null;
  }
}

/**
 * Get existing cart or create a new one.
 */
export async function getOrCreateCart(): Promise<StoreOrder & { token: string }> {
  const existing = await getCart();
  if (existing) return existing;

  const token = await getAccessToken();
  const cart = await getClient().store.cart.create(token ? { token } : undefined);

  if (cart.token) {
    await setCartToken(cart.token);
  }

  revalidateTag('cart');
  return cart;
}

/**
 * Add an item to the cart. Creates a cart if none exists.
 * Returns the updated order with recalculated totals.
 */
export async function addItem(
  variantId: string,
  quantity: number = 1,
  metadata?: Record<string, unknown>
): Promise<StoreOrder> {
  const cart = await getOrCreateCart();
  const orderToken = cart.token;
  const token = await getAccessToken();

  const order = await getClient().store.orders.lineItems.create(
    cart.id,
    { variant_id: variantId, quantity, metadata },
    { orderToken, token }
  );

  revalidateTag('cart');
  return order;
}

/**
 * Update a line item in the cart (quantity and/or metadata).
 * Returns the updated order with recalculated totals.
 *
 * @example
 *   // Update quantity only
 *   await updateItem(lineItemId, { quantity: 3 })
 *
 *   // Update metadata only
 *   await updateItem(lineItemId, { metadata: { gift_message: 'Happy Birthday!' } })
 *
 *   // Update both
 *   await updateItem(lineItemId, { quantity: 2, metadata: { engraving: 'J.D.' } })
 */
export async function updateItem(
  lineItemId: string,
  params: { quantity?: number; metadata?: Record<string, unknown> }
): Promise<StoreOrder> {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  if (!orderToken && !token) throw new Error('No cart found');

  const cart = await getClient().store.cart.get({ orderToken, token });

  const order = await getClient().store.orders.lineItems.update(
    cart.id,
    lineItemId,
    params,
    { orderToken, token }
  );

  revalidateTag('cart');
  return order;
}

/**
 * Remove a line item from the cart.
 * Returns the updated order with recalculated totals.
 */
export async function removeItem(lineItemId: string): Promise<StoreOrder> {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  if (!orderToken && !token) throw new Error('No cart found');

  const cart = await getClient().store.cart.get({ orderToken, token });

  const order = await getClient().store.orders.lineItems.delete(cart.id, lineItemId, {
    orderToken,
    token,
  });

  revalidateTag('cart');
  return order;
}

/**
 * Clear the cart (abandons the current cart).
 */
export async function clearCart(): Promise<void> {
  await clearCartToken();
  revalidateTag('cart');
}

/**
 * Associate a guest cart with the currently authenticated user.
 * Call this after login/register when the user has an existing guest cart.
 */
export async function associateCart(): Promise<(StoreOrder & { token: string }) | null> {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  if (!orderToken || !token) return null;

  try {
    const result = await getClient().store.cart.associate({ orderToken, token });
    revalidateTag('cart');
    return result;
  } catch {
    // Cart might already belong to another user — clear it
    await clearCartToken();
    revalidateTag('cart');
    return null;
  }
}
