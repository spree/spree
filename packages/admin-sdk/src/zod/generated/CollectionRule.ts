// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CollectionRuleSchema = z.object({
  id: z.string(),
  match_policy: z.string(),
  currency: z.string().nullable(),
  value: z.string().nullable(),
  preferences: z.record(z.string(), z.unknown()),
  type: z.string(),
});

export type CollectionRule = z.infer<typeof CollectionRuleSchema>;
