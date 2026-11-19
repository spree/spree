// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type GiftCard from '../../types/generated/GiftCard';
import { AdminUserSchema } from './AdminUser';
import { CustomFieldSchema } from './CustomField';
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
  custom_fields: z.array(CustomFieldSchema).optional(),
  created_at: z.string(),
  updated_at: z.string(),
  customer_id: z.string().nullable(),
  created_by_id: z.string().nullable(),
  get customer() { return CustomerSchema.optional(); },
  created_by: AdminUserSchema.optional(),
  gift_card_batch: GiftCardBatchSchema.optional(),
  get orders() { return z.array(OrderSchema).optional(); },
}) as unknown as z.ZodObject<{
  id: z.ZodType<GiftCard['id']>;
  code: z.ZodType<GiftCard['code']>;
  status: z.ZodType<GiftCard['status']>;
  currency: z.ZodType<GiftCard['currency']>;
  amount: z.ZodType<GiftCard['amount']>;
  amount_used: z.ZodType<GiftCard['amount_used']>;
  amount_authorized: z.ZodType<GiftCard['amount_authorized']>;
  amount_remaining: z.ZodType<GiftCard['amount_remaining']>;
  expires_at: z.ZodType<GiftCard['expires_at']>;
  redeemed_at: z.ZodType<GiftCard['redeemed_at']>;
  expired: z.ZodType<GiftCard['expired']>;
  active: z.ZodType<GiftCard['active']>;
  custom_fields: z.ZodOptional<z.ZodType<Exclude<GiftCard['custom_fields'], undefined>>>;
  created_at: z.ZodType<GiftCard['created_at']>;
  updated_at: z.ZodType<GiftCard['updated_at']>;
  customer_id: z.ZodType<GiftCard['customer_id']>;
  created_by_id: z.ZodType<GiftCard['created_by_id']>;
  customer: z.ZodOptional<z.ZodType<Exclude<GiftCard['customer'], undefined>>>;
  created_by: z.ZodOptional<z.ZodType<Exclude<GiftCard['created_by'], undefined>>>;
  gift_card_batch: z.ZodOptional<z.ZodType<Exclude<GiftCard['gift_card_batch'], undefined>>>;
  orders: z.ZodOptional<z.ZodType<Exclude<GiftCard['orders'], undefined>>>;
}>;

export type { GiftCard };
