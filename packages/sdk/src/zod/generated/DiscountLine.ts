// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DiscountLineSchema = z.object({
  id: z.string(),
  label: z.string(),
  display_amount: z.string(),
  kind: z.string().nullable(),
  amount: z.string(),
  promotion_id: z.string().nullable(),
});

export type DiscountLine = z.infer<typeof DiscountLineSchema>;
