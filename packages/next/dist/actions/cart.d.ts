import { StoreLineItem, StoreOrder } from '@spree/sdk';

/**
 * Get the current cart. Returns null if no cart exists.
 */
declare function getCart(): Promise<(StoreOrder & {
    token: string;
}) | null>;
/**
 * Get existing cart or create a new one.
 */
declare function getOrCreateCart(): Promise<StoreOrder & {
    token: string;
}>;
/**
 * Add an item to the cart. Creates a cart if none exists.
 */
declare function addItem(variantId: string, quantity?: number): Promise<StoreLineItem>;
/**
 * Update a line item quantity in the cart.
 */
declare function updateItem(lineItemId: string, quantity: number): Promise<StoreLineItem>;
/**
 * Remove a line item from the cart.
 */
declare function removeItem(lineItemId: string): Promise<void>;
/**
 * Clear the cart (abandons the current cart).
 */
declare function clearCart(): Promise<void>;
/**
 * Associate a guest cart with the currently authenticated user.
 * Call this after login/register when the user has an existing guest cart.
 */
declare function associateCart(): Promise<(StoreOrder & {
    token: string;
}) | null>;

export { addItem, associateCart, clearCart, getCart, getOrCreateCart, removeItem, updateItem };
