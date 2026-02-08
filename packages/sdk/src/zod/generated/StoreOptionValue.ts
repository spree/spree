// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreOptionValueSchema = z.object({
  id: z.string(),
  option_type_id: z.string(),
  name: z.string(),
  presentation: z.string(),
  position: z.number(),
  option_type_name: z.string(),
  option_type_presentation: z.string(),
});

export type StoreOptionValue = z.infer<typeof StoreOptionValueSchema>;
