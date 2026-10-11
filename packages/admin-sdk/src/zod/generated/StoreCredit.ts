// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminUserSchema } from './AdminUser';
import { CustomerSchema } from './Customer';

export const StoreCreditSchema = z.object({
  id: z.string(),
  amount: z.string(),
  amount_used: z.string(),
  amount_remaining: z.string(),
  currency: z.string(),
  memo: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  amount_authorized: z.string(),
  outstanding: z.boolean(),
  customer_id: z.string().nullable(),
  created_by_id: z.string().nullable(),
  originator_type: z.string().nullable(),
  originator_id: z.string().nullable(),
  get customer() { return CustomerSchema.optional(); },
  created_by: AdminUserSchema.optional(),
});

export type StoreCredit = z.infer<typeof StoreCreditSchema>;
