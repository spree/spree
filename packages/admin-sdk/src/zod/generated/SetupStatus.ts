// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SetupStatusSchema = z.object({
  setup_required: z.boolean(),
});

export type SetupStatus = z.infer<typeof SetupStatusSchema>;
