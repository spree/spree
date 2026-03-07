import { describe, it, expect, beforeAll } from 'vitest';
import { createAdminTestClient } from '../helpers';
import { adminFixtures } from '../mocks/admin-handlers';
import type { SpreeClient } from '../../src';

describe('admin / orders', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createAdminTestClient(); });

  describe('list', () => {
    it('returns paginated orders', async () => {
      const result = await client.admin.orders.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].number).toBe('R100001');
      expect(result.meta.page).toBe(1);
    });
  });

  describe('create', () => {
    it('creates a draft order', async () => {
      const result = await client.admin.orders.create({
        email: 'new-order@example.com',
      });

      expect(result.email).toBe('new-order@example.com');
    });
  });

  describe('get', () => {
    it('returns an order by ID', async () => {
      const result = await client.admin.orders.get('or_1');

      expect(result.id).toBe(adminFixtures.order.id);
      expect(result.email).toBe('admin@example.com');
    });
  });

  describe('update', () => {
    it('updates an order', async () => {
      const result = await client.admin.orders.update('or_1', {
        email: 'updated@example.com',
      });

      expect(result.email).toBe('updated@example.com');
    });
  });

  describe('delete', () => {
    it('deletes a draft order', async () => {
      await expect(
        client.admin.orders.delete('or_1')
      ).resolves.toBeUndefined();
    });
  });

  describe('cancel', () => {
    it('cancels an order', async () => {
      const result = await client.admin.orders.cancel('or_1');

      expect(result.state).toBe('canceled');
    });
  });

  describe('approve', () => {
    it('approves an order', async () => {
      const result = await client.admin.orders.approve('or_1');

      expect(result.approved_at).toBe('2026-03-06T12:00:00.000Z');
    });
  });

  describe('resume', () => {
    it('resumes a canceled order', async () => {
      const result = await client.admin.orders.resume('or_1');

      expect(result.state).toBe('resumed');
    });
  });

  describe('resendConfirmation', () => {
    it('resends confirmation email', async () => {
      const result = await client.admin.orders.resendConfirmation('or_1');

      expect(result.id).toBe(adminFixtures.order.id);
    });
  });

  describe('lineItems', () => {
    it('lists line items', async () => {
      const result = await client.admin.orders.lineItems.list('or_1');

      expect(result.data).toHaveLength(1);
      expect(result.data[0].quantity).toBe(2);
    });

    it('creates a line item', async () => {
      const result = await client.admin.orders.lineItems.create('or_1', {
        variant_id: 'var_1',
        quantity: 2,
      });

      expect(result.variant_id).toBe('var_1');
      expect(result.quantity).toBe(2);
    });

    it('gets a line item', async () => {
      const result = await client.admin.orders.lineItems.get('or_1', 'li_1');

      expect(result.id).toBe(adminFixtures.lineItem.id);
    });

    it('updates a line item', async () => {
      const result = await client.admin.orders.lineItems.update('or_1', 'li_1', {
        quantity: 5,
      });

      expect(result.quantity).toBe(5);
    });

    it('deletes a line item', async () => {
      await expect(
        client.admin.orders.lineItems.delete('or_1', 'li_1')
      ).resolves.toBeUndefined();
    });
  });
});
