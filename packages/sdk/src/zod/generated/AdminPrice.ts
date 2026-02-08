// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminPriceSchema = z.object({
  id: z.string(),
  amount: z.string().nullable(),
  amount_in_cents: z.number().nullable(),
  compare_at_amount: z.string().nullable(),
  compare_at_amount_in_cents: z.number().nullable(),
  currency: z.string().nullable(),
  display_amount: z.string().nullable(),
  display_compare_at_amount: z.string().nullable(),
  price_list_id: z.string().nullable(),
  variant_id: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type AdminPrice = z.infer<typeof AdminPriceSchema>;
