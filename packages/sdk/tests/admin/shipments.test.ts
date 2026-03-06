import { describe, it, expect, beforeAll } from 'vitest';
import { createAdminTestClient } from '../helpers';
import { adminFixtures } from '../mocks/admin-handlers';
import type { SpreeClient } from '../../src';

describe('admin / orders.shipments', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createAdminTestClient(); });

  const orderId = 'or_1';

  describe('list', () => {
    it('returns paginated shipments', async () => {
      const result = await client.admin.orders.shipments.list(orderId);

      expect(result.data).toHaveLength(1);
      expect(result.data[0].number).toBe('H12345');
      expect(result.meta.page).toBe(1);
    });
  });

  describe('get', () => {
    it('returns a shipment by ID', async () => {
      const result = await client.admin.orders.shipments.get(orderId, 'ship_1');

      expect(result.id).toBe(adminFixtures.shipment.id);
      expect(result.state).toBe('ready');
    });
  });

  describe('update', () => {
    it('updates tracking on a shipment', async () => {
      const result = await client.admin.orders.shipments.update(orderId, 'ship_1', {
        tracking: '1Z999AA10123456784',
      });

      expect(result.tracking).toBe('1Z999AA10123456784');
    });
  });

  describe('ship', () => {
    it('ships a shipment', async () => {
      const result = await client.admin.orders.shipments.ship(orderId, 'ship_1');

      expect(result.state).toBe('shipped');
      expect(result.shipped_at).toBeTruthy();
    });
  });

  describe('cancel', () => {
    it('cancels a shipment', async () => {
      const result = await client.admin.orders.shipments.cancel(orderId, 'ship_1');

      expect(result.state).toBe('canceled');
    });
  });

  describe('resume', () => {
    it('resumes a canceled shipment', async () => {
      const result = await client.admin.orders.shipments.resume(orderId, 'ship_1');

      expect(result.state).toBe('ready');
    });
  });

  describe('split', () => {
    it('splits a shipment to a new stock location', async () => {
      const result = await client.admin.orders.shipments.split(orderId, 'ship_1', {
        variant_id: 'var_1',
        quantity: 1,
        stock_location_id: 'sl_2',
      });

      expect(result.data).toHaveLength(2);
      expect(result.data[0].id).toBe('ship_1');
      expect(result.data[1].id).toBe('ship_2');
    });
  });
});
