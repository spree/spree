// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ActorSchema = z.object({
  id: z.string(),
  type: z.string(),
  label: z.string().nullable(),
});

export type Actor = z.infer<typeof ActorSchema>;
