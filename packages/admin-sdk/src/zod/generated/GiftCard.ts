// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type GiftCard from '../../types/generated/GiftCard';
import { AdminUserSchema } from './AdminUser';
import { CustomerSchema } from './Customer';
import { GiftCardBatchSchema } from './GiftCardBatch';
import { OrderSchema } from './Order';

export const GiftCardSchema = z.object({
  id: z.string(),
  code: z.string(),
  status: z.string(),
  currency: z.string(),
  amount: z.string(),
  amount_used: z.string(),
  amount_authorized: z.string(),
  amount_remaining: z.string(),
  expires_at: z.string().nullable(),
  redeemed_at: z.string().nullable(),
  expired: z.boolean(),
  active: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  customer_id: z.string().nullable(),
  created_by_id: z.string().nullable(),
  get customer() { return CustomerSchema.optional(); },
  created_by: AdminUserSchema.optional(),
  gift_card_batch: GiftCardBatchSchema.optional(),
  get orders() { return z.array(OrderSchema).optional(); },
}) as unknown as z.ZodType<GiftCard>;

export type { GiftCard };
