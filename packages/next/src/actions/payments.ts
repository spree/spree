'use server';

import { revalidateTag } from 'next/cache';
import type { Payment, CreatePaymentParams } from '@spree/sdk';
import { getClient } from '../config';
import { getCartToken, getAccessToken } from '../cookies';

async function getCheckoutOptions() {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  return { orderToken, token };
}

/**
 * Create a payment for a non-session payment method (e.g. Check, Cash on Delivery, Bank Transfer).
 * For session-based payment methods (e.g. Stripe, PayPal), use createPaymentSession instead.
 */
export async function createPayment(
  orderId: string,
  params: CreatePaymentParams
): Promise<Payment> {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.payments.create(orderId, params, options);
  revalidateTag('checkout');
  return result;
}
