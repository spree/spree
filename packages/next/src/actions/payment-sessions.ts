'use server';

import { revalidateTag } from 'next/cache';
import type {
  PaymentSession,
  CreatePaymentSessionParams,
  UpdatePaymentSessionParams,
  CompletePaymentSessionParams,
} from '@spree/sdk';
import { getClient } from '../config';
import { getCheckoutOptions } from '../cookies';

/**
 * Create a payment session for the current cart.
 * Delegates to the payment gateway to initialize a provider-specific session.
 */
export async function createPaymentSession(
  params: CreatePaymentSessionParams
): Promise<PaymentSession> {
  const options = await getCheckoutOptions();
  const result = await getClient().checkout.paymentSessions.create(params, options);
  revalidateTag('checkout');
  return result;
}

/**
 * Get a payment session by ID.
 */
export async function getPaymentSession(
  sessionId: string
): Promise<PaymentSession> {
  const options = await getCheckoutOptions();
  return getClient().checkout.paymentSessions.get(sessionId, options);
}

/**
 * Update a payment session.
 * Delegates to the payment gateway to sync changes with the provider.
 */
export async function updatePaymentSession(
  sessionId: string,
  params: UpdatePaymentSessionParams
): Promise<PaymentSession> {
  const options = await getCheckoutOptions();
  const result = await getClient().checkout.paymentSessions.update(sessionId, params, options);
  revalidateTag('checkout');
  return result;
}

/**
 * Complete a payment session.
 * Confirms the payment with the provider, triggering capture/authorization.
 */
export async function completePaymentSession(
  sessionId: string,
  params?: CompletePaymentSessionParams
): Promise<PaymentSession> {
  const options = await getCheckoutOptions();
  const result = await getClient().checkout.paymentSessions.complete(sessionId, params, options);
  revalidateTag('checkout');
  return result;
}
