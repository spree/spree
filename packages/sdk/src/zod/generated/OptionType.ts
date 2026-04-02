// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OptionTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  label: z.string(),
  position: z.number(),
  kind: z.string(),
});

export type OptionType = z.infer<typeof OptionTypeSchema>;
