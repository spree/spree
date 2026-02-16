'use server';

import { revalidateTag } from 'next/cache';
import type {
  StorePaymentSession,
  CreatePaymentSessionParams,
  UpdatePaymentSessionParams,
  CompletePaymentSessionParams,
} from '@spree/sdk';
import { getClient } from '../config';
import { getCartToken, getAccessToken } from '../cookies';

async function getCheckoutOptions() {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  return { orderToken, token };
}

/**
 * Create a payment session for an order.
 * Delegates to the payment gateway to initialize a provider-specific session.
 */
export async function createPaymentSession(
  orderId: string,
  params: CreatePaymentSessionParams
): Promise<StorePaymentSession> {
  const options = await getCheckoutOptions();
  const result = await getClient().store.orders.paymentSessions.create(orderId, params, options);
  revalidateTag('checkout');
  return result;
}

/**
 * Get a payment session by ID.
 */
export async function getPaymentSession(
  orderId: string,
  sessionId: string
): Promise<StorePaymentSession> {
  const options = await getCheckoutOptions();
  return getClient().store.orders.paymentSessions.get(orderId, sessionId, options);
}

/**
 * Update a payment session.
 * Delegates to the payment gateway to sync changes with the provider.
 */
export async function updatePaymentSession(
  orderId: string,
  sessionId: string,
  params: UpdatePaymentSessionParams
): Promise<StorePaymentSession> {
  const options = await getCheckoutOptions();
  const result = await getClient().store.orders.paymentSessions.update(orderId, sessionId, params, options);
  revalidateTag('checkout');
  return result;
}

/**
 * Complete a payment session.
 * Confirms the payment with the provider, triggering capture/authorization.
 */
export async function completePaymentSession(
  orderId: string,
  sessionId: string,
  params?: CompletePaymentSessionParams
): Promise<StorePaymentSession> {
  const options = await getCheckoutOptions();
  const result = await getClient().store.orders.paymentSessions.complete(orderId, sessionId, params, options);
  revalidateTag('checkout');
  return result;
}
