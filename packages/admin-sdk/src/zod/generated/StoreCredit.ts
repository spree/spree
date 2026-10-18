// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type StoreCredit from '../../types/generated/StoreCredit';
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
}) as unknown as z.ZodObject<{
  id: z.ZodType<StoreCredit['id']>;
  amount: z.ZodType<StoreCredit['amount']>;
  amount_used: z.ZodType<StoreCredit['amount_used']>;
  amount_remaining: z.ZodType<StoreCredit['amount_remaining']>;
  currency: z.ZodType<StoreCredit['currency']>;
  memo: z.ZodType<StoreCredit['memo']>;
  metadata: z.ZodType<StoreCredit['metadata']>;
  created_at: z.ZodType<StoreCredit['created_at']>;
  updated_at: z.ZodType<StoreCredit['updated_at']>;
  amount_authorized: z.ZodType<StoreCredit['amount_authorized']>;
  outstanding: z.ZodType<StoreCredit['outstanding']>;
  customer_id: z.ZodType<StoreCredit['customer_id']>;
  created_by_id: z.ZodType<StoreCredit['created_by_id']>;
  originator_type: z.ZodType<StoreCredit['originator_type']>;
  originator_id: z.ZodType<StoreCredit['originator_id']>;
  customer: z.ZodOptional<z.ZodType<Exclude<StoreCredit['customer'], undefined>>>;
  created_by: z.ZodOptional<z.ZodType<Exclude<StoreCredit['created_by'], undefined>>>;
}>;

export type { StoreCredit };
