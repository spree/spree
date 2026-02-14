'use server';

import { revalidateTag } from 'next/cache';
import type { StoreCreditCard } from '@spree/sdk';
import { withAuthRefresh } from '../auth-helpers';
import { getClient } from '../config';

/**
 * List the authenticated customer's credit cards.
 */
export async function listCreditCards(): Promise<{ data: StoreCreditCard[] }> {
  return withAuthRefresh(async (options) => {
    return getClient().store.customer.creditCards.list(undefined, options);
  });
}

/**
 * Delete a credit card.
 */
export async function deleteCreditCard(id: string): Promise<void> {
  await withAuthRefresh(async (options) => {
    return getClient().store.customer.creditCards.delete(id, options);
  });
  revalidateTag('credit-cards');
}
