import { describe, it, expect, beforeAll } from 'vitest';
import { createAdminTestClient } from '../helpers';
import { adminFixtures } from '../mocks/admin-handlers';
import type { SpreeClient } from '../../src';

describe('admin / orders.refunds', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createAdminTestClient(); });

  const orderId = 'or_1';

  describe('list', () => {
    it('returns paginated refunds', async () => {
      const result = await client.admin.orders.refunds.list(orderId);

      expect(result.data).toHaveLength(1);
      expect(result.data[0].amount).toBe('5.0');
      expect(result.meta.page).toBe(1);
    });
  });

  describe('create', () => {
    it('creates a refund', async () => {
      const result = await client.admin.orders.refunds.create(orderId, {
        payment_id: 'py_1',
        amount: 5.0,
        refund_reason_id: 'rr_1',
      });

      expect(result.id).toBe(adminFixtures.refund.id);
      expect(result.amount).toBe('5.0');
      expect(result.payment_id).toBe('py_1');
    });
  });
});
