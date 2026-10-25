// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CustomFieldSchema = z.object({
  id: z.string(),
  label: z.string(),
  field_type: z.string(),
  key: z.string(),
  value: z.any(),
  created_at: z.string(),
  updated_at: z.string(),
  storefront_visible: z.boolean(),
  custom_field_definition_id: z.string(),
});

export type CustomField = z.infer<typeof CustomFieldSchema>;
