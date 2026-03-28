'use server';

import { updateTag } from 'next/cache';
import type { CreditCard } from '@spree/sdk';
import { withAuthRefresh } from '../auth-helpers';
import { getClient } from '../config';

/**
 * List the authenticated customer's credit cards.
 */
export async function listCreditCards(): Promise<{ data: CreditCard[] }> {
  return withAuthRefresh(async (options) => {
    return getClient().customer.creditCards.list(undefined, options);
  });
}

/**
 * Delete a credit card.
 */
export async function deleteCreditCard(id: string): Promise<void> {
  await withAuthRefresh(async (options) => {
    return getClient().customer.creditCards.delete(id, options);
  });
  updateTag('credit-cards');
}
