// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const RequirementCustomFieldSchema = z.object({
  id: z.string(),
  key: z.string(),
  label: z.string(),
  field_type: z.string(),
  value: z.any(),
});

export type RequirementCustomField = z.infer<typeof RequirementCustomFieldSchema>;
