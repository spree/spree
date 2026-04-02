// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OptionValueSchema = z.object({
  id: z.string(),
  option_type_id: z.string(),
  name: z.string(),
  label: z.string(),
  position: z.number(),
  color_code: z.string().nullable(),
  option_type_name: z.string(),
  option_type_label: z.string(),
  image_url: z.string().nullable(),
});

export type OptionValue = z.infer<typeof OptionValueSchema>;
