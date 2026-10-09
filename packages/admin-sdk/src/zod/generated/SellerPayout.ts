// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SellerPayoutSchema = z.object({
  id: z.string(),
  status: z.string(),
  currency: z.string(),
  reference: z.string().nullable(),
  metadata: z.unknown(),
  period_start: z.string().nullable(),
  period_end: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  amount: z.string(),
  seller_id: z.string(),
  seller_name: z.string().nullable(),
  transfers_count: z.number(),
  provider: z.string(),
});

export type SellerPayout = z.infer<typeof SellerPayoutSchema>;
