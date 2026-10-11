// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliveryMethodRuleSchema = z.object({
  id: z.string(),
  active: z.boolean(),
  type: z.string(),
  preferences: z.record(z.string(), z.unknown()),
});

export type DeliveryMethodRule = z.infer<typeof DeliveryMethodRuleSchema>;
