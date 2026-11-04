// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PaymentMethodRuleSchema = z.object({
  id: z.string(),
  active: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  type: z.string(),
  preferences: z.record(z.string(), z.unknown()),
});

export type PaymentMethodRule = z.infer<typeof PaymentMethodRuleSchema>;
