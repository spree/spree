// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SellerTransferSchema = z.object({
  id: z.string(),
  kind: z.string(),
  status: z.string(),
  currency: z.string(),
  reference: z.string().nullable(),
  metadata: z.unknown(),
  created_at: z.string(),
  updated_at: z.string(),
  amount: z.string(),
  settled_amount: z.string().nullable(),
  settled_currency: z.string().nullable(),
  converted: z.boolean(),
  seller_id: z.string(),
  order_id: z.string().nullable(),
  payout_id: z.string().nullable(),
  reversed_from_id: z.string().nullable(),
  refund_id: z.string().nullable(),
  seller_name: z.string().nullable(),
  order_number: z.string().nullable(),
  provider: z.string(),
});

export type SellerTransfer = z.infer<typeof SellerTransferSchema>;
