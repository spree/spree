import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { SpreeClient } from '../src';

describe('wishlists', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });
  const opts = { token: 'user-jwt' };

  it('lists wishlists', async () => {
    const result = await client.store.wishlists.list(undefined, opts);
    expect(result.data).toHaveLength(1);
  });

  it('gets a wishlist', async () => {
    const result = await client.store.wishlists.get('wl_1', undefined, opts);
    expect(result.name).toBe('My Wishlist');
  });

  it('creates a wishlist', async () => {
    const result = await client.store.wishlists.create(
      { name: 'My Wishlist' },
      opts
    );
    expect(result.name).toBe('My Wishlist');
  });

  it('updates a wishlist', async () => {
    const result = await client.store.wishlists.update(
      'wl_1',
      { name: 'Updated Wishlist' },
      opts
    );
    expect(result.name).toBe('Updated Wishlist');
  });

  it('deletes a wishlist', async () => {
    await expect(
      client.store.wishlists.delete('wl_1', opts)
    ).resolves.toBeUndefined();
  });

  describe('items', () => {
    it('adds an item', async () => {
      const result = await client.store.wishlists.items.create(
        'wl_1',
        { variant_id: 'var_1', quantity: 1 },
        opts
      );
      expect(result.variant_id).toBe('var_1');
    });

    it('updates an item', async () => {
      const result = await client.store.wishlists.items.update(
        'wl_1',
        'wi_1',
        { quantity: 3 },
        opts
      );
      expect(result.quantity).toBe(3);
    });

    it('removes an item', async () => {
      await expect(
        client.store.wishlists.items.delete('wl_1', 'wi_1', opts)
      ).resolves.toBeUndefined();
    });
  });
});
