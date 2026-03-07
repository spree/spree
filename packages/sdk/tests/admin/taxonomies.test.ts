import { describe, it, expect, beforeAll } from 'vitest';
import { createAdminTestClient } from '../helpers';
import { adminFixtures } from '../mocks/admin-handlers';
import type { SpreeClient } from '../../src';

describe('admin / taxonomies', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createAdminTestClient(); });

  describe('list', () => {
    it('returns paginated taxonomies', async () => {
      const result = await client.admin.taxonomies.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].name).toBe('Categories');
      expect(result.meta.page).toBe(1);
    });
  });

  describe('create', () => {
    it('creates a taxonomy', async () => {
      const result = await client.admin.taxonomies.create({
        name: 'Categories',
      });

      expect(result.name).toBe(adminFixtures.taxonomy.name);
    });
  });

  describe('get', () => {
    it('returns a taxonomy by ID', async () => {
      const result = await client.admin.taxonomies.get('txmy_1');

      expect(result.name).toBe(adminFixtures.taxonomy.name);
    });
  });

  describe('update', () => {
    it('updates a taxonomy', async () => {
      const result = await client.admin.taxonomies.update('txmy_1', {
        name: 'Updated Categories',
      });

      expect(result.name).toBe('Updated Categories');
    });
  });

  describe('delete', () => {
    it('deletes a taxonomy', async () => {
      await expect(
        client.admin.taxonomies.delete('txmy_1')
      ).resolves.toBeUndefined();
    });
  });

  describe('taxons', () => {
    it('lists taxonomy taxons', async () => {
      const result = await client.admin.taxonomies.taxons.list('txmy_1');

      expect(result.data).toHaveLength(1);
      expect(result.data[0].name).toBe('Clothing');
    });

    it('creates a taxon', async () => {
      const result = await client.admin.taxonomies.taxons.create('txmy_1', {
        name: 'Clothing',
      });

      expect(result.name).toBe(adminFixtures.taxon.name);
    });

    it('gets a taxon', async () => {
      const result = await client.admin.taxonomies.taxons.get('txmy_1', 'txon_1');

      expect(result.id).toBe(adminFixtures.taxon.id);
    });

    it('updates a taxon', async () => {
      const result = await client.admin.taxonomies.taxons.update('txmy_1', 'txon_1', {
        name: 'Updated Clothing',
      });

      expect(result.name).toBe('Updated Clothing');
    });

    it('deletes a taxon', async () => {
      await expect(
        client.admin.taxonomies.taxons.delete('txmy_1', 'txon_1')
      ).resolves.toBeUndefined();
    });
  });
});
