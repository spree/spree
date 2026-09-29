// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductTypeCustomFieldDefinitionSchema = z.object({
  id: z.string(),
  key: z.string(),
  namespace: z.string(),
  label: z.string(),
  field_type: z.string(),
  required: z.boolean(),
  sort_order: z.number(),
});

export type ProductTypeCustomFieldDefinition = z.infer<typeof ProductTypeCustomFieldDefinitionSchema>;
