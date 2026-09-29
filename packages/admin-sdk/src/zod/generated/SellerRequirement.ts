// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SellerRequirementSchema = z.object({
  id: z.string(),
  position: z.number(),
  active: z.boolean(),
  required: z.boolean(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  kind: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  preferences: z.record(z.string(), z.unknown()),
  custom_field_definition_ids: z.array(z.string()),
  allow_multiple: z.boolean(),
  accepts_submissions: z.boolean(),
  reviewed_by_operator: z.boolean(),
});

export type SellerRequirement = z.infer<typeof SellerRequirementSchema>;
