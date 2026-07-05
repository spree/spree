// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DiscountSchema = z.object({
  id: z.string(),
  promotion_id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  code: z.string().nullable(),
  amount: z.string().nullable(),
  display_amount: z.string().nullable(),
});

export type Discount = z.infer<typeof DiscountSchema>;
