'use server';

import { revalidateTag } from 'next/cache';
import type { Payment, CreatePaymentParams } from '@spree/sdk';
import { getClient } from '../config';
import { getCheckoutOptions, getCartId } from '../cookies';

/**
 * Create a payment for a non-session payment method (e.g. Check, Cash on Delivery, Bank Transfer).
 * For session-based payment methods (e.g. Stripe, PayPal), use createPaymentSession instead.
 */
export async function createPayment(
  params: CreatePaymentParams
): Promise<Payment> {
  const options = await getCheckoutOptions();
  const cartId = await getCartId();
  if (!cartId) throw new Error('No cart found');
  const result = await getClient().carts.payments.create(cartId, params, options);
  revalidateTag('checkout');
  return result;
}
