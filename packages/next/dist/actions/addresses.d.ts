import { AddressParams, StoreAddress } from '@spree/sdk';

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

export { createAddress, deleteAddress, getAddress, listAddresses, updateAddress };
