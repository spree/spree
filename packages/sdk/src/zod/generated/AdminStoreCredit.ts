// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminStoreCreditSchema = z.object({
  id: z.string(),
  amount: z.string(),
  amount_used: z.string(),
  amount_remaining: z.string(),
  display_amount: z.string(),
  display_amount_used: z.string(),
  display_amount_remaining: z.string(),
  currency: z.string(),
  user_id: z.string().nullable(),
  created_by_id: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type AdminStoreCredit = z.infer<typeof AdminStoreCreditSchema>;
