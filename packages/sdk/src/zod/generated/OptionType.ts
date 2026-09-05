// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { OptionValueSchema } from './OptionValue';

export const OptionTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  label: z.string(),
  position: z.number(),
  kind: z.string(),
  option_values: z.array(OptionValueSchema).optional(),
});

export type OptionType = z.infer<typeof OptionTypeSchema>;
