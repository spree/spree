import { StoreCreditCard } from '@spree/sdk';

/**
 * List the authenticated customer's credit cards.
 */
declare function listCreditCards(): Promise<{
    data: StoreCreditCard[];
}>;
/**
 * Delete a credit card.
 */
declare function deleteCreditCard(id: string): Promise<void>;

export { deleteCreditCard, listCreditCards };
