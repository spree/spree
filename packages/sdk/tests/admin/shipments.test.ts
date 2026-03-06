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
});
