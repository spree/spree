// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CouponCodeSchema = z.object({
  id: z.string(),
  code: z.string(),
  state: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  promotion_id: z.string(),
  order_id: z.string().nullable(),
});

export type CouponCode = z.infer<typeof CouponCodeSchema>;
