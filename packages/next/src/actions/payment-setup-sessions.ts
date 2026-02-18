'use server';

import type {
  StorePaymentSetupSession,
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
): Promise<StorePaymentSetupSession> {
  return withAuthRefresh(async (options) => {
    return getClient().store.customer.paymentSetupSessions.create(params, options);
  });
}

/**
 * Get a payment setup session by ID.
 */
export async function getPaymentSetupSession(
  id: string
): Promise<StorePaymentSetupSession> {
  return withAuthRefresh(async (options) => {
    return getClient().store.customer.paymentSetupSessions.get(id, options);
  });
}

/**
 * Complete a payment setup session.
 * Confirms the setup with the provider, resulting in a saved payment method.
 */
export async function completePaymentSetupSession(
  id: string,
  params?: CompletePaymentSetupSessionParams
): Promise<StorePaymentSetupSession> {
  return withAuthRefresh(async (options) => {
    return getClient().store.customer.paymentSetupSessions.complete(id, params, options);
  });
}
