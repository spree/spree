// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CustomFieldChoiceSchema = z.object({
  value: z.string(),
  label: z.string(),
});

export type CustomFieldChoice = z.infer<typeof CustomFieldChoiceSchema>;
