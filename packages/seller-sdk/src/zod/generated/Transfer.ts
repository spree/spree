// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TransferSchema = z.object({
  id: z.string(),
  kind: z.string(),
  status: z.string(),
  currency: z.string(),
  reference: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  amount: z.string(),
  settled_amount: z.string().nullable(),
  settled_currency: z.string().nullable(),
  converted: z.boolean(),
  order_id: z.string().nullable(),
  payout_id: z.string().nullable(),
  reversed_from_id: z.string().nullable(),
  order_number: z.string().nullable(),
  provider: z.string(),
});

export type Transfer = z.infer<typeof TransferSchema>;
