// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliveryMethodRuleSchema = z.object({
  id: z.string(),
  active: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  type: z.string(),
  preferences: z.record(z.string(), z.unknown()),
  product_ids: z.array(z.string()),
});

export type DeliveryMethodRule = z.infer<typeof DeliveryMethodRuleSchema>;
