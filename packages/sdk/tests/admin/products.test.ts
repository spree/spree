import { describe, it, expect, beforeAll } from 'vitest';
import { createAdminTestClient } from '../helpers';
import { adminFixtures } from '../mocks/admin-handlers';
import type { SpreeClient } from '../../src';

describe('admin / products', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createAdminTestClient(); });

  describe('list', () => {
    it('returns paginated products', async () => {
      const result = await client.admin.products.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].name).toBe('Admin Product');
      expect(result.meta.page).toBe(1);
    });
  });

  describe('create', () => {
    it('creates a product', async () => {
      const result = await client.admin.products.create({
        name: 'New Product',
        price: 29.99,
        shipping_category_id: 'sc_1',
      });

      expect(result.name).toBe(adminFixtures.product.name);
    });
  });

  describe('get', () => {
    it('returns a product by ID', async () => {
      const result = await client.admin.products.get('prod_1');

      expect(result.name).toBe(adminFixtures.product.name);
      expect(result.slug).toBe('admin-product');
    });
  });

  describe('update', () => {
    it('updates a product', async () => {
      const result = await client.admin.products.update('prod_1', {
        name: 'Updated Product',
      });

      expect(result.name).toBe('Updated Product');
    });
  });

  describe('delete', () => {
    it('deletes a product', async () => {
      await expect(
        client.admin.products.delete('prod_1')
      ).resolves.toBeUndefined();
    });
  });

  describe('assets', () => {
    it('lists product assets', async () => {
      const result = await client.admin.products.assets.list('prod_1');

      expect(result.data).toHaveLength(1);
      expect(result.data[0].alt).toBe('Product image');
    });

    it('creates an asset', async () => {
      const result = await client.admin.products.assets.create('prod_1', {
        alt: 'New image',
      });

      expect(result.alt).toBe(adminFixtures.asset.alt);
    });

    it('creates an asset from URL (returns 202)', async () => {
      await expect(
        client.admin.products.assets.create('prod_1', {
          url: 'https://example.com/image.jpg',
          position: 1,
        })
      ).resolves.toBeFalsy();
    });

    it('updates an asset', async () => {
      const result = await client.admin.products.assets.update('prod_1', 'asset_1', {
        alt: 'Updated alt',
      });

      expect(result.alt).toBe('Updated alt');
    });

    it('deletes an asset', async () => {
      await expect(
        client.admin.products.assets.delete('prod_1', 'asset_1')
      ).resolves.toBeUndefined();
    });
  });

  describe('variants', () => {
    it('lists product variants', async () => {
      const result = await client.admin.products.variants.list('prod_1');

      expect(result.data).toHaveLength(1);
      expect(result.data[0].sku).toBe('VAR-001');
    });

    it('creates a variant', async () => {
      const result = await client.admin.products.variants.create('prod_1', {
        sku: 'VAR-NEW',
        price: 19.99,
      });

      expect(result.sku).toBe(adminFixtures.variant.sku);
    });

    it('gets a variant', async () => {
      const result = await client.admin.products.variants.get('prod_1', 'var_1');

      expect(result.id).toBe(adminFixtures.variant.id);
    });

    it('updates a variant', async () => {
      const result = await client.admin.products.variants.update('prod_1', 'var_1', {
        sku: 'VAR-UPDATED',
      });

      expect(result.sku).toBe('VAR-UPDATED');
    });

    it('deletes a variant', async () => {
      await expect(
        client.admin.products.variants.delete('prod_1', 'var_1')
      ).resolves.toBeUndefined();
    });

    describe('assets', () => {
      it('lists variant assets', async () => {
        const result = await client.admin.products.variants.assets.list('prod_1', 'var_1');

        expect(result.data).toHaveLength(1);
        expect(result.data[0].alt).toBe('Product image');
      });

      it('creates a variant asset', async () => {
        const result = await client.admin.products.variants.assets.create('prod_1', 'var_1', {
          alt: 'Variant image',
        });

        expect(result.alt).toBe(adminFixtures.asset.alt);
      });

      it('creates a variant asset from URL (returns 202)', async () => {
        await expect(
          client.admin.products.variants.assets.create('prod_1', 'var_1', {
            url: 'https://example.com/variant.jpg',
          })
        ).resolves.toBeFalsy();
      });

      it('updates a variant asset', async () => {
        const result = await client.admin.products.variants.assets.update('prod_1', 'var_1', 'asset_1', {
          alt: 'Updated variant alt',
        });

        expect(result.alt).toBe('Updated variant alt');
      });

      it('deletes a variant asset', async () => {
        await expect(
          client.admin.products.variants.assets.delete('prod_1', 'var_1', 'asset_1')
        ).resolves.toBeUndefined();
      });
    });
  });
});
