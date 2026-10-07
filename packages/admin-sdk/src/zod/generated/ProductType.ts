// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ProductTypeCustomFieldDefinitionSchema } from './ProductTypeCustomFieldDefinition';

export const ProductTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  translations: z.record(z.string(), z.record(z.string(), z.union([z.string(), z.number()]).nullable())).optional(),
  products_count: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  delivery_profile_id: z.string().nullable(),
  option_type_ids: z.array(z.string()),
  category_ids: z.array(z.string()),
  custom_field_definitions: z.array(ProductTypeCustomFieldDefinitionSchema),
});

export type ProductType = z.infer<typeof ProductTypeSchema>;
