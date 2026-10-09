// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PriceSchema = z.object({
  id: z.string(),
  currency: z.string().nullable(),
  amount: z.string().nullable(),
  compare_at_amount: z.string().nullable(),
  display_amount: z.string().nullable(),
  display_compare_at_amount: z.string().nullable(),
  price_list_id: z.string().nullable(),
});

export type Price = z.infer<typeof PriceSchema>;
