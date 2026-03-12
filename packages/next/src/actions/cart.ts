'use server';

import { revalidateTag } from 'next/cache';
import type { Cart, CreateCartParams } from '@spree/sdk';
import { getClient } from '../config';
import { getCartToken, setCartToken, clearCartToken, getAccessToken } from '../cookies';

/**
 * Get the current cart. Returns null if no cart exists.
 */
export async function getCart(): Promise<Cart | null> {
  const spreeToken = await getCartToken();
  const token = await getAccessToken();
  if (!spreeToken && !token) return null;

  try {
    return await getClient().cart.get({ spreeToken, token });
  } catch {
    // Cart not found (e.g., order was completed) — clear stale token
    if (spreeToken) {
      await clearCartToken();
    }
    return null;
  }
}

/**
 * Get existing cart or create a new one.
 * @param params - Optional cart creation params (metadata, line_items)
 */
export async function getOrCreateCart(
  params?: CreateCartParams
): Promise<Cart> {
  const existing = await getCart();
  if (existing) return existing;

  const token = await getAccessToken();
  const cartParams = params && Object.keys(params).length > 0 ? params : undefined;
  const cart = await getClient().cart.create(cartParams, token ? { token } : undefined);

  if (cart.token) {
    await setCartToken(cart.token);
  }

  revalidateTag('cart');
  return cart;
}

/**
 * Add an item to the cart. Creates a cart if none exists.
 * Returns the updated cart with recalculated totals.
 */
export async function addItem(
  variantId: string,
  quantity: number = 1,
  metadata?: Record<string, unknown>
): Promise<Cart> {
  await getOrCreateCart();
  const spreeToken = await getCartToken();
  const token = await getAccessToken();

  const cart = await getClient().cart.items.create(
    { variant_id: variantId, quantity, metadata },
    { spreeToken, token }
  );

  revalidateTag('cart');
  return cart;
}

/**
 * Update a line item in the cart (quantity and/or metadata).
 * Returns the updated cart with recalculated totals.
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
): Promise<Cart> {
  const spreeToken = await getCartToken();
  const token = await getAccessToken();
  if (!spreeToken && !token) throw new Error('No cart found');

  const cart = await getClient().cart.items.update(
    lineItemId,
    params,
    { spreeToken, token }
  );

  revalidateTag('cart');
  return cart;
}

/**
 * Remove a line item from the cart.
 * Returns the updated cart with recalculated totals.
 */
export async function removeItem(lineItemId: string): Promise<Cart> {
  const spreeToken = await getCartToken();
  const token = await getAccessToken();
  if (!spreeToken && !token) throw new Error('No cart found');

  const cart = await getClient().cart.items.delete(lineItemId, {
    spreeToken,
    token,
  });

  revalidateTag('cart');
  return cart;
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
export async function associateCart(): Promise<Cart | null> {
  const spreeToken = await getCartToken();
  const token = await getAccessToken();
  if (!spreeToken || !token) return null;

  try {
    const result = await getClient().cart.associate({ spreeToken, token });
    revalidateTag('cart');
    return result;
  } catch {
    // Cart might already belong to another user — clear it
    await clearCartToken();
    revalidateTag('cart');
    return null;
  }
}
