// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StateSchema = z.object({
  abbr: z.string(),
  name: z.string(),
});

export type State = z.infer<typeof StateSchema>;
