// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AppliedPromotionSchema = z.object({
  id: z.string(),
  promotion_id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  code: z.string().nullable(),
  amount: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type AppliedPromotion = z.infer<typeof AppliedPromotionSchema>;
