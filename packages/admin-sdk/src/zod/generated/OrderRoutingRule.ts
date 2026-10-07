// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OrderRoutingRuleSchema = z.object({
  id: z.string(),
  position: z.number(),
  active: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  type: z.string(),
  channel_id: z.string(),
  preferences: z.record(z.string(), z.unknown()),
  preference_schema: z.array(z.object({ key: z.string(), type: z.string(), default: z.unknown(), choices: z.array(z.object({ value: z.string(), label: z.string().optional() })).optional() })),
});

export type OrderRoutingRule = z.infer<typeof OrderRoutingRuleSchema>;
