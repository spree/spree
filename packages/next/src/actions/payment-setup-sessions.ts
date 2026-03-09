'use server';

import type {
  PaymentSetupSession,
  CreatePaymentSetupSessionParams,
  CompletePaymentSetupSessionParams,
} from '@spree/sdk';
import { withAuthRefresh } from '../auth-helpers';
import { getClient } from '../config';

/**
 * Create a payment setup session for saving a payment method.
 * Delegates to the payment gateway to initialize a setup flow.
 */
export async function createPaymentSetupSession(
  params: CreatePaymentSetupSessionParams
): Promise<PaymentSetupSession> {
  return withAuthRefresh(async (options) => {
    return getClient().customer.paymentSetupSessions.create(params, options);
  });
}

/**
 * Get a payment setup session by ID.
 */
export async function getPaymentSetupSession(
  id: string
): Promise<PaymentSetupSession> {
  return withAuthRefresh(async (options) => {
    return getClient().customer.paymentSetupSessions.get(id, options);
  });
}

/**
 * Complete a payment setup session.
 * Confirms the setup with the provider, resulting in a saved payment method.
 */
export async function completePaymentSetupSession(
  id: string,
  params?: CompletePaymentSetupSessionParams
): Promise<PaymentSetupSession> {
  return withAuthRefresh(async (options) => {
    return getClient().customer.paymentSetupSessions.complete(id, params, options);
  });
}
