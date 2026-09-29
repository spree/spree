// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PromotionSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  code: z.string().nullable(),
  starts_at: z.string().nullable(),
  expires_at: z.string().nullable(),
  usage_limit: z.number().nullable(),
  match_policy: z.string(),
  path: z.string().nullable(),
  kind: z.string(),
  multi_codes: z.boolean(),
  number_of_codes: z.number().nullable(),
  code_prefix: z.string().nullable(),
  promotion_category_id: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  action_ids: z.array(z.string()),
  rule_ids: z.array(z.string()),
});

export type Promotion = z.infer<typeof PromotionSchema>;
