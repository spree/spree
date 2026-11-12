// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PriceHistorySchema = z.object({
  id: z.string(),
  currency: z.string(),
  amount: z.string().nullable(),
  recorded_at: z.string(),
});

export type PriceHistory = z.infer<typeof PriceHistorySchema>;
