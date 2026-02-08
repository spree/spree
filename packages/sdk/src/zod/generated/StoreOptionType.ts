// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreOptionTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  presentation: z.string(),
  position: z.number(),
});

export type StoreOptionType = z.infer<typeof StoreOptionTypeSchema>;
