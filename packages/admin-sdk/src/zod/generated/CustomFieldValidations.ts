// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CustomFieldChoiceSchema } from './CustomFieldChoice';

export const CustomFieldValidationsSchema = z.object({
  required: z.boolean(),
  min: z.union([z.number(), z.string()]).nullable(),
  max: z.union([z.number(), z.string()]).nullable(),
  multiple: z.boolean(),
  choices: z.array(CustomFieldChoiceSchema),
});

export type CustomFieldValidations = z.infer<typeof CustomFieldValidationsSchema>;
