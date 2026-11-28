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
});

export type CustomFieldDefinition = z.infer<typeof CustomFieldDefinitionSchema>;
