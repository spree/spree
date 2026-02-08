// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreStateSchema = z.object({
  abbr: z.string(),
  name: z.string(),
});

export type StoreState = z.infer<typeof StoreStateSchema>;
