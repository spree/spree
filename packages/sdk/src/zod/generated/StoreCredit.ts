// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreCreditSchema = z.object({
  id: z.string(),
  amount: z.string().nullable(),
  amount_used: z.string().nullable(),
  amount_remaining: z.string().nullable(),
  display_amount: z.string().nullable(),
  display_amount_used: z.string().nullable(),
  display_amount_remaining: z.string().nullable(),
  currency: z.string(),
});

export type StoreCredit = z.infer<typeof StoreCreditSchema>;
