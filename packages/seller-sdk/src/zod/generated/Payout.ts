// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PayoutSchema = z.object({
  id: z.string(),
  status: z.string(),
  currency: z.string(),
  provider: z.string(),
  reference: z.string().nullable(),
  period_start: z.string().nullable(),
  period_end: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  amount: z.string(),
  display_amount: z.string(),
  transfers_count: z.number(),
});

export type Payout = z.infer<typeof PayoutSchema>;
