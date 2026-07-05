// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PriceHistorySchema = z.object({
  id: z.string(),
  amount: z.string(),
  amount_in_cents: z.number(),
  currency: z.string(),
  display_amount: z.string(),
  recorded_at: z.string(),
});

export type PriceHistory = z.infer<typeof PriceHistorySchema>;
