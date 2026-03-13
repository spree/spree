'use server';

import { revalidateTag } from 'next/cache';
import type { Cart, CreateCartParams } from '@spree/sdk';
import { getClient } from '../config';
import {
  getCartToken, setCartToken, clearCartToken,
  getCartId, setCartId, clearCartId,
  getAccessToken,
} from '../cookies';

/**
 * Get the current cart. Returns null if no cart exists.
 */
export async function getCart(): Promise<Cart | null> {
  const spreeToken = await getCartToken();
  const token = await getAccessToken();
  const cartId = await getCartId();

  if (!cartId && !token) return null;

  try {
    if (cartId) {
      return await getClient().carts.get(cartId, { spreeToken, token });
    }

    // Authenticated user without stored cart ID — find their most recent cart
    if (token) {
      const response = await getClient().carts.list({ token });
      if (response.data.length > 0) {
        const cart = response.data[0];
        await setCartId(cart.id);
        if (cart.token) await setCartToken(cart.token);
        return cart;
      }
    }

    return null;
  } catch {
    // Cart not found (e.g., order was completed) — clear stale cookies
    await clearCartToken();
    await clearCartId();
    return null;
  }
}

/**
 * Get existing cart or create a new one.
 * @param params - Optional cart creation params (metadata, items)
 */
export async function getOrCreateCart(
  params?: CreateCartParams
): Promise<Cart> {
  const existing = await getCart();
  if (existing) return existing;

  const token = await getAccessToken();
  const cartParams = params && Object.keys(params).length > 0 ? params : undefined;
  const cart = await getClient().carts.create(cartParams, token ? { token } : undefined);

  if (cart.token) {
    await setCartToken(cart.token);
  }
  await setCartId(cart.id);

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
  const cart = await getOrCreateCart();
  const spreeToken = await getCartToken();
  const token = await getAccessToken();

  const updatedCart = await getClient().carts.items.create(
    cart.id,
    { variant_id: variantId, quantity, metadata },
    { spreeToken, token }
  );

  revalidateTag('cart');
  return updatedCart;
}

/**
 * Update a line item in the cart (quantity and/or metadata).
 * Returns the updated cart with recalculated totals.
 */
export async function updateItem(
  lineItemId: string,
  params: { quantity?: number; metadata?: Record<string, unknown> }
): Promise<Cart> {
  const spreeToken = await getCartToken();
  const token = await getAccessToken();
  const cartId = await requireCartId();

  const cart = await getClient().carts.items.update(
    cartId,
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
  const cartId = await requireCartId();

  const cart = await getClient().carts.items.delete(cartId, lineItemId, {
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
  await clearCartId();
  revalidateTag('cart');
}

/**
 * Associate a guest cart with the currently authenticated user.
 * Call this after login/register when the user has an existing guest cart.
 */
export async function associateCart(): Promise<Cart | null> {
  const spreeToken = await getCartToken();
  const token = await getAccessToken();
  const cartId = await getCartId();
  if (!cartId || !token) return null;

  try {
    const result = await getClient().carts.associate(cartId, { spreeToken, token });
    revalidateTag('cart');
    return result;
  } catch {
    // Cart might already belong to another user — clear it
    await clearCartToken();
    await clearCartId();
    revalidateTag('cart');
    return null;
  }
}

async function requireCartId(): Promise<string> {
  const cartId = await getCartId();
  if (!cartId) throw new Error('No cart found');
  return cartId;
}
