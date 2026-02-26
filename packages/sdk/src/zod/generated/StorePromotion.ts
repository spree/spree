// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StorePromotionSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  code: z.string().nullable(),
  type: z.string().nullable(),
  kind: z.string().nullable(),
  path: z.string().nullable(),
  match_policy: z.string().nullable(),
  usage_limit: z.number().nullable(),
  advertise: z.boolean(),
  multi_codes: z.boolean(),
  code_prefix: z.string().nullable(),
  number_of_codes: z.number().nullable(),
  starts_at: z.string().nullable(),
  expires_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  promotion_category_id: z.string().nullable(),
});

export type StorePromotion = z.infer<typeof StorePromotionSchema>;
