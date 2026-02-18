import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import type { SpreeClient } from '../src';

describe('paymentSetupSessions', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });
  const opts = { token: 'user-jwt' };

  describe('create', () => {
    it('creates a payment setup session', async () => {
      const result = await client.store.customer.paymentSetupSessions.create(
        { payment_method_id: 'pm_1' },
        opts
      );
      expect(result.id).toBe('pss_1');
      expect(result.status).toBe('pending');
      expect(result.payment_method_id).toBe('pm_1');
      expect(result.external_client_secret).toBe('seti_secret_xyz');
    });

    it('accepts optional external_data', async () => {
      const result = await client.store.customer.paymentSetupSessions.create(
        { payment_method_id: 'pm_1', external_data: { channel: 'Web' } },
        opts
      );
      expect(result.id).toBe('pss_1');
    });
  });

  describe('get', () => {
    it('returns a payment setup session by ID', async () => {
      const result = await client.store.customer.paymentSetupSessions.get(
        'pss_1',
        opts
      );
      expect(result.id).toBe('pss_1');
      expect(result.status).toBe('pending');
      expect(result.external_id).toBe('seti_abc123');
      expect(result.customer_id).toBe('user_1');
    });
  });

  describe('complete', () => {
    it('completes a payment setup session', async () => {
      const result = await client.store.customer.paymentSetupSessions.complete(
        'pss_1',
        undefined,
        opts
      );
      expect(result.id).toBe('pss_1');
      expect(result.status).toBe('completed');
      expect(result.payment_source_id).toBe('cc_1');
      expect(result.payment_source_type).toBe('Spree::CreditCard');
    });

    it('completes with external_data', async () => {
      const result = await client.store.customer.paymentSetupSessions.complete(
        'pss_1',
        { external_data: { setup_intent_id: 'seti_123' } },
        opts
      );
      expect(result.status).toBe('completed');
    });
  });
});
