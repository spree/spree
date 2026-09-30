// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CommissionRuleSchema } from './CommissionRule';

export const CommissionRateSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string().nullable(),
  enabled: z.boolean(),
  position: z.number(),
  kind: z.string(),
  tax_inclusive: z.boolean(),
  include_shipping: z.boolean(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  deleted_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  value: z.string(),
  commission_tax_rate: z.string().nullable(),
  amounts: z.record(z.string(), z.string()),
  bounds: z.record(z.string(), z.object({ min_amount: z.string().nullable(), max_amount: z.string().nullable() })),
  global: z.boolean(),
  rules: z.array(CommissionRuleSchema),
});

export type CommissionRate = z.infer<typeof CommissionRateSchema>;
