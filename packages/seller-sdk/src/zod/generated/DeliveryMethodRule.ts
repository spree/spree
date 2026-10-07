// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliveryMethodRuleSchema = z.object({
  id: z.string(),
  active: z.boolean(),
  type: z.string(),
  preferences: z.record(z.string(), z.unknown()),
  preference_schema: z.array(z.object({ key: z.string(), type: z.string(), default: z.unknown(), choices: z.array(z.object({ value: z.string(), label: z.string().optional() })).optional() })),
});

export type DeliveryMethodRule = z.infer<typeof DeliveryMethodRuleSchema>;
