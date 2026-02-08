export { getClient, initSpreeNext } from './config.js';
export { SpreeNextConfig, SpreeNextOptions } from './types.js';
export { getProduct, getProductFilters, listProducts } from './data/products.js';
export { getTaxon, listTaxonProducts, listTaxons } from './data/taxons.js';
export { getTaxonomy, listTaxonomies } from './data/taxonomies.js';
export { getStore } from './data/store.js';
export { getCountry, listCountries } from './data/countries.js';
import { StoreLineItem, StoreOrder, StoreShipment, AddressParams, StoreUser, StoreAddress, PaginatedResponse, StoreCreditCard, StoreGiftCard } from '@spree/sdk';
export { AddressParams, PaginatedResponse, ProductFiltersResponse, SpreeError, StoreAddress, StoreCountry, StoreCreditCard, StoreGiftCard, StoreImage, StoreLineItem, StoreOptionType, StoreOptionValue, StoreOrder, StoreOrderPromotion, StorePayment, StorePaymentMethod, StorePrice, StoreProduct, StoreShipment, StoreShippingRate, StoreStore, StoreTaxon, StoreTaxonomy, StoreUser, StoreVariant } from '@spree/sdk';

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

/**
 * Get the current checkout order state.
 */
declare function getCheckout(orderId: string): Promise<StoreOrder>;
/**
 * Update shipping and/or billing addresses on the order.
 */
declare function updateAddresses(orderId: string, params: {
    email?: string;
    ship_address?: AddressParams;
    bill_address?: AddressParams;
    ship_address_id?: string;
    bill_address_id?: string;
}): Promise<StoreOrder>;
/**
 * Advance the checkout to the next step.
 */
declare function advance(orderId: string): Promise<StoreOrder>;
/**
 * Move the checkout to the next step (alias for advance).
 */
declare function next(orderId: string): Promise<StoreOrder>;
/**
 * Get shipments for the order (includes available shipping rates).
 */
declare function getShipments(orderId: string): Promise<{
    data: StoreShipment[];
}>;
/**
 * Select a shipping rate for a shipment.
 */
declare function selectShippingRate(orderId: string, shipmentId: string, shippingRateId: string): Promise<StoreShipment>;
/**
 * Apply a coupon code to the order.
 */
declare function applyCoupon(orderId: string, code: string): Promise<StoreOrder>;
/**
 * Remove a coupon/promotion from the order.
 */
declare function removeCoupon(orderId: string, promotionId: string): Promise<StoreOrder>;
/**
 * Complete the checkout and place the order.
 */
declare function complete(orderId: string): Promise<StoreOrder>;

/**
 * Login with email and password.
 * Automatically associates any guest cart with the authenticated user.
 */
declare function login(email: string, password: string): Promise<{
    success: boolean;
    user?: {
        id: string;
        email: string;
        first_name?: string | null;
        last_name?: string | null;
    };
    error?: string;
}>;
/**
 * Register a new customer account.
 * Automatically associates any guest cart with the new account.
 */
declare function register(email: string, password: string, passwordConfirmation: string): Promise<{
    success: boolean;
    user?: {
        id: string;
        email: string;
        first_name?: string | null;
        last_name?: string | null;
    };
    error?: string;
}>;
/**
 * Logout the current user.
 */
declare function logout(): Promise<void>;
/**
 * Get the currently authenticated customer. Returns null if not logged in.
 */
declare function getCustomer(): Promise<StoreUser | null>;
/**
 * Update the current customer's profile.
 */
declare function updateCustomer(data: {
    first_name?: string;
    last_name?: string;
    email?: string;
}): Promise<StoreUser>;

/**
 * List the authenticated customer's addresses.
 */
declare function listAddresses(): Promise<{
    data: StoreAddress[];
}>;
/**
 * Get a single address by ID.
 */
declare function getAddress(id: string): Promise<StoreAddress>;
/**
 * Create a new address for the customer.
 */
declare function createAddress(params: AddressParams): Promise<StoreAddress>;
/**
 * Update an existing address.
 */
declare function updateAddress(id: string, params: Partial<AddressParams>): Promise<StoreAddress>;
/**
 * Delete an address.
 */
declare function deleteAddress(id: string): Promise<void>;

/**
 * List the authenticated customer's orders.
 */
declare function listOrders(params?: Record<string, unknown>): Promise<PaginatedResponse<StoreOrder>>;
/**
 * Get a single order by ID or number.
 */
declare function getOrder(idOrNumber: string, params?: Record<string, unknown>): Promise<StoreOrder>;

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

export { addItem, advance, applyCoupon, associateCart, clearCart, complete, createAddress, deleteAddress, deleteCreditCard, getAddress, getCart, getCheckout, getCustomer, getGiftCard, getOrCreateCart, getOrder, getShipments, listAddresses, listCreditCards, listGiftCards, listOrders, login, logout, next, register, removeCoupon, removeItem, selectShippingRate, updateAddress, updateAddresses, updateCustomer, updateItem };
