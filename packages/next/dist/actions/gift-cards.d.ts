import { StoreGiftCard } from '@spree/sdk';

/**
 * List the authenticated customer's gift cards.
 */
declare function listGiftCards(): Promise<{
    data: StoreGiftCard[];
}>;
/**
 * Get a single gift card by ID.
 */
declare function getGiftCard(id: string): Promise<StoreGiftCard>;

export { getGiftCard, listGiftCards };
