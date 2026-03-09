// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OptionTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  presentation: z.string(),
  position: z.number(),
});

export type OptionType = z.infer<typeof OptionTypeSchema>;
