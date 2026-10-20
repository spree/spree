// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PromotionActionSchema = z.object({
  id: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  type: z.string(),
  promotion_id: z.string(),
  preferences: z.record(z.string(), z.unknown()),
  calculator: z.any().nullable(),
  line_items: z.array(z.object({ variant_id: z.string(), quantity: z.number() })).nullable(),
});

export type PromotionAction = z.infer<typeof PromotionActionSchema>;
