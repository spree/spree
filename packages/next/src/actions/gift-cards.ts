'use server';

import type { StoreGiftCard } from '@spree/sdk';
import { withAuthRefresh } from '../auth-helpers';
import { getClient } from '../config';

/**
 * List the authenticated customer's gift cards.
 */
export async function listGiftCards(): Promise<{ data: StoreGiftCard[] }> {
  return withAuthRefresh(async (options) => {
    return getClient().customer.giftCards.list(undefined, options);
  });
}

/**
 * Get a single gift card by ID.
 */
export async function getGiftCard(id: string): Promise<StoreGiftCard> {
  return withAuthRefresh(async (options) => {
    return getClient().customer.giftCards.get(id, options);
  });
}
