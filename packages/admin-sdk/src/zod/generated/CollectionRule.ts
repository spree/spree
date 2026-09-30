// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CollectionRuleSchema = z.object({
  id: z.string(),
  value: z.string().nullable(),
  match_policy: z.string(),
  type: z.string(),
});

export type CollectionRule = z.infer<typeof CollectionRuleSchema>;
