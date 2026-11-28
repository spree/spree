// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CustomFieldValidationsSchema } from './CustomFieldValidations';

export const CustomFieldDefinitionSchema = z.object({
  id: z.string(),
  namespace: z.string(),
  key: z.string(),
  full_key: z.string(),
  label: z.string(),
  field_type: z.string(),
  resource_type: z.string(),
  validations: CustomFieldValidationsSchema,
  storefront_visible: z.boolean(),
  storefront_writable: z.boolean(),
  searchable: z.boolean(),
  sortable: z.boolean(),
  filter_key: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type CustomFieldDefinition = z.infer<typeof CustomFieldDefinitionSchema>;
