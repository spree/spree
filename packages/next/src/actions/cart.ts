'use server';

import { updateTag } from 'next/cache';
import type { Cart, Order, CreateCartParams, UpdateCartParams } from '@spree/sdk';
import { getClient } from '../config';
import {
  getCartToken, getCartId,
  setCartCookies, clearCartCookies,
  getAccessToken,
  getCartOptions, requireCartId,
} from '../cookies';

/**
 * Get the current cart. Returns null if no cart exists.
 * @param explicitCartId - Optional cart ID to fetch directly, bypassing cookie lookup.
 */
export async function getCart(explicitCartId?: string): Promise<Cart | null> {
  const spreeToken = await getCartToken();
  const token = await getAccessToken();
  const cartId = explicitCartId ?? await getCartId();

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
        await setCartCookies(cart.id, cart.token);
        return cart;
      }
    }

    return null;
  } catch {
    // Cart not found (e.g., order was completed) — clear stale cookies
    if (!explicitCartId) {
      await clearCartCookies();
    }
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

  await setCartCookies(cart.id, cart.token);

  updateTag('cart');
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

  updateTag('cart');
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
  const options = await getCartOptions();
  const cartId = await requireCartId();

  const cart = await getClient().carts.items.update(
    cartId,
    lineItemId,
    params,
    options
  );

  updateTag('cart');
  return cart;
}

/**
 * Remove a line item from the cart.
 * Returns the updated cart with recalculated totals.
 */
export async function removeItem(lineItemId: string): Promise<Cart> {
  const options = await getCartOptions();
  const cartId = await requireCartId();

  const cart = await getClient().carts.items.delete(cartId, lineItemId, options);

  updateTag('cart');
  return cart;
}

/**
 * Clear the cart (abandons the current cart).
 */
export async function clearCart(): Promise<void> {
  await clearCartCookies();
  updateTag('cart');
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
    updateTag('cart');
    return result;
  } catch {
    // Cart might already belong to another user — clear it
    await clearCartCookies();
    updateTag('cart');
    return null;
  }
}

/**
 * Update cart info (email, addresses, special instructions).
 */
export async function updateCart(
  params: UpdateCartParams
): Promise<Cart> {
  const options = await getCartOptions();
  const cartId = await requireCartId();
  const result = await getClient().carts.update(cartId, params, options);
  updateTag('checkout');
  return result;
}

/**
 * Select a delivery rate for a fulfillment.
 * Returns the updated cart with recalculated totals.
 */
export async function selectDeliveryRate(
  fulfillmentId: string,
  deliveryRateId: string
): Promise<Cart> {
  const options = await getCartOptions();
  const cartId = await requireCartId();
  const result = await getClient().carts.fulfillments.update(
    cartId,
    fulfillmentId,
    { selected_delivery_rate_id: deliveryRateId },
    options
  );
  updateTag('checkout');
  return result;
}

/**
 * Apply a discount code to the cart.
 */
export async function applyDiscountCode(
  code: string
): Promise<Cart> {
  const options = await getCartOptions();
  const cartId = await requireCartId();
  const result = await getClient().carts.discountCodes.apply(cartId, code, options);
  updateTag('checkout');
  updateTag('cart');
  return result;
}

/**
 * Remove a discount code from the cart.
 */
export async function removeDiscountCode(
  code: string
): Promise<Cart> {
  const options = await getCartOptions();
  const cartId = await requireCartId();
  const result = await getClient().carts.discountCodes.remove(cartId, code, options);
  updateTag('checkout');
  updateTag('cart');
  return result;
}

/**
 * Apply a gift card to the cart.
 * Gift cards are treated as a payment method — the cart total stays the same
 * while `amount_due` is reduced.
 */
export async function applyGiftCard(
  code: string
): Promise<Cart> {
  const options = await getCartOptions();
  const cartId = await requireCartId();
  const result = await getClient().carts.giftCards.apply(cartId, code, options);
  updateTag('checkout');
  updateTag('cart');
  return result;
}

/**
 * Remove the applied gift card from the cart.
 * @param giftCardId - Gift card prefixed ID (e.g., 'gc_abc123') from cart.gift_card.id
 */
export async function removeGiftCard(giftCardId: string): Promise<Cart> {
  const options = await getCartOptions();
  const cartId = await requireCartId();
  const result = await getClient().carts.giftCards.remove(cartId, giftCardId, options);
  updateTag('checkout');
  updateTag('cart');
  return result;
}

/**
 * Complete the checkout and place the order.
 * @param explicitCartId - Optional cart ID to complete. If not provided, uses the cart cookie.
 */
export async function complete(explicitCartId?: string): Promise<Order> {
  const options = await getCartOptions();
  const cartId = explicitCartId ?? await requireCartId();
  const result = await getClient().carts.complete(cartId, options);
  updateTag('checkout');
  updateTag('cart');
  return result;
}
