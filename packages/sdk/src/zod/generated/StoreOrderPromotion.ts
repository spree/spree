// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreOrderPromotionSchema = z.object({
  id: z.string(),
  promotion_id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  code: z.string().nullable(),
  amount: z.string(),
  display_amount: z.string(),
});

export type StoreOrderPromotion = z.infer<typeof StoreOrderPromotionSchema>;
