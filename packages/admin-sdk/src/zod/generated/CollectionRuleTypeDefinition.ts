// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CollectionRuleTypeDefinitionSchema = z.object({
  type: z.string(),
  label: z.string(),
  description: z.string().nullable(),
  schema: z.any(),
  superseded: z.boolean().optional(),
  match_policies: z.array(z.string()),
  value_required: z.boolean(),
  uses_currency: z.boolean(),
});

export type CollectionRuleTypeDefinition = z.infer<typeof CollectionRuleTypeDefinitionSchema>;
