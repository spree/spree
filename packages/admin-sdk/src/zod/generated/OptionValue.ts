// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { OptionTypeSchema } from './OptionType';

export const OptionValueSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  option_type_id: z.string(),
  name: z.string(),
  label: z.string(),
  position: z.number(),
  color_code: z.string().nullable(),
  option_type_name: z.string(),
  option_type_label: z.string(),
  image_url: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  option_type: z.lazy(() => OptionTypeSchema).optional(),
});

export type OptionValue = z.infer<typeof OptionValueSchema>;
