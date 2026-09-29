// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SetupTaskSchema = z.object({
  name: z.string(),
  done: z.boolean(),
});

export type SetupTask = z.infer<typeof SetupTaskSchema>;
