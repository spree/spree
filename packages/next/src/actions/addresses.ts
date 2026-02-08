'use server';

import { revalidateTag } from 'next/cache';
import type { StoreAddress, AddressParams } from '@spree/sdk';
import { withAuthRefresh } from '../auth-helpers';
import { getClient } from '../config';

/**
 * List the authenticated customer's addresses.
 */
export async function listAddresses(): Promise<{ data: StoreAddress[] }> {
  return withAuthRefresh(async (options) => {
    return getClient().customer.addresses.list(undefined, options);
  });
}

/**
 * Get a single address by ID.
 */
export async function getAddress(id: string): Promise<StoreAddress> {
  return withAuthRefresh(async (options) => {
    return getClient().customer.addresses.get(id, options);
  });
}

/**
 * Create a new address for the customer.
 */
export async function createAddress(params: AddressParams): Promise<StoreAddress> {
  const result = await withAuthRefresh(async (options) => {
    return getClient().customer.addresses.create(params, options);
  });
  revalidateTag('addresses');
  return result;
}

/**
 * Update an existing address.
 */
export async function updateAddress(
  id: string,
  params: Partial<AddressParams>
): Promise<StoreAddress> {
  const result = await withAuthRefresh(async (options) => {
    return getClient().customer.addresses.update(id, params, options);
  });
  revalidateTag('addresses');
  return result;
}

/**
 * Delete an address.
 */
export async function deleteAddress(id: string): Promise<void> {
  await withAuthRefresh(async (options) => {
    return getClient().customer.addresses.delete(id, options);
  });
  revalidateTag('addresses');
}
