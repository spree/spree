// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { OptionValueSchema } from './OptionValue';

export const OptionTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  label: z.string(),
  position: z.number(),
  kind: z.string(),
  translations: z.record(z.string(), z.record(z.string(), z.union([z.string(), z.number()]).nullable())).optional(),
  metadata: z.record(z.string(), z.unknown()),
  filterable: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  get option_values() { return z.array(OptionValueSchema).optional(); },
});

export type OptionType = z.infer<typeof OptionTypeSchema>;
