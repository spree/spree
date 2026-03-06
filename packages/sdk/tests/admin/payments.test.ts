import { describe, it, expect, beforeAll } from 'vitest';
import { createAdminTestClient } from '../helpers';
import { adminFixtures } from '../mocks/admin-handlers';
import type { SpreeClient } from '../../src';

describe('admin / orders.payments', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createAdminTestClient(); });

  const orderId = 'or_1';

  describe('list', () => {
    it('returns paginated payments', async () => {
      const result = await client.admin.orders.payments.list(orderId);

      expect(result.data).toHaveLength(1);
      expect(result.data[0].number).toBe('P100001');
      expect(result.meta.page).toBe(1);
    });
  });

  describe('create', () => {
    it('creates a payment', async () => {
      const result = await client.admin.orders.payments.create(orderId, {
        payment_method_id: 'pm_1',
        amount: 29.99,
      });

      expect(result.id).toBe(adminFixtures.payment.id);
      expect(result.amount).toBe('29.99');
    });
  });

  describe('get', () => {
    it('returns a payment by ID', async () => {
      const result = await client.admin.orders.payments.get(orderId, 'py_1');

      expect(result.id).toBe(adminFixtures.payment.id);
      expect(result.state).toBe('completed');
    });
  });

  describe('capture', () => {
    it('captures a payment', async () => {
      const result = await client.admin.orders.payments.capture(orderId, 'py_1');

      expect(result.state).toBe('completed');
    });
  });

  describe('void', () => {
    it('voids a payment', async () => {
      const result = await client.admin.orders.payments.void(orderId, 'py_1');

      expect(result.state).toBe('void');
    });
  });
});
