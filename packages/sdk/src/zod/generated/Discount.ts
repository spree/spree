// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DiscountSchema = z.object({
  id: z.string(),
  label: z.string(),
  kind: z.string(),
  code: z.string().nullable(),
  value_type: z.string().nullable(),
  value: z.string().nullable(),
  promotion_id: z.string().nullable(),
  line_item_id: z.string().nullable(),
  fulfillment_id: z.string().nullable(),
  amount: z.string().nullable(),
  display_amount: z.string().nullable(),
});

export type Discount = z.infer<typeof DiscountSchema>;
