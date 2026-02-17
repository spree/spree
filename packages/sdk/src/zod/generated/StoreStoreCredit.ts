// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreStoreCreditSchema = z.object({
  id: z.string(),
  amount: z.string(),
  amount_used: z.string(),
  amount_remaining: z.string(),
  display_amount: z.string(),
  display_amount_used: z.string(),
  display_amount_remaining: z.string(),
  currency: z.string(),
});

export type StoreStoreCredit = z.infer<typeof StoreStoreCreditSchema>;
