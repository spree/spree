// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreGiftCardBatchSchema = z.object({
  id: z.string(),
  codes_count: z.number(),
  currency: z.string().nullable(),
  prefix: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  amount: z.string().nullable(),
  expires_at: z.string().nullable(),
  created_by_id: z.string().nullable(),
});

export type StoreGiftCardBatch = z.infer<typeof StoreGiftCardBatchSchema>;
