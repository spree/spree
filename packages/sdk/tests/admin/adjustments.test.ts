import { describe, it, expect, beforeAll } from 'vitest';
import { createAdminTestClient } from '../helpers';
import { adminFixtures } from '../mocks/admin-handlers';
import type { SpreeClient } from '../../src';

describe('admin / orders.adjustments', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createAdminTestClient(); });

  const orderId = 'or_1';

  describe('list', () => {
    it('returns paginated adjustments', async () => {
      const result = await client.admin.orders.adjustments.list(orderId);

      expect(result.data).toHaveLength(1);
      expect(result.data[0].label).toBe('Admin discount');
      expect(result.meta.page).toBe(1);
    });
  });

  describe('create', () => {
    it('creates an adjustment', async () => {
      const result = await client.admin.orders.adjustments.create(orderId, {
        amount: -5.0,
        label: 'Admin discount',
      });

      expect(result.id).toBe(adminFixtures.adjustment.id);
      expect(result.amount).toBe('-5.0');
      expect(result.label).toBe('Admin discount');
    });
  });

  describe('get', () => {
    it('returns an adjustment by ID', async () => {
      const result = await client.admin.orders.adjustments.get(orderId, 'adj_1');

      expect(result.id).toBe(adminFixtures.adjustment.id);
      expect(result.eligible).toBe(true);
    });
  });

  describe('update', () => {
    it('updates an adjustment', async () => {
      const result = await client.admin.orders.adjustments.update(orderId, 'adj_1', {
        amount: 10.0,
        label: 'Updated discount',
      });

      expect(result.amount).toBe('10.0');
      expect(result.label).toBe('Updated discount');
    });
  });

  describe('delete', () => {
    it('deletes an adjustment', async () => {
      await expect(
        client.admin.orders.adjustments.delete(orderId, 'adj_1')
      ).resolves.toBeUndefined();
    });
  });
});
