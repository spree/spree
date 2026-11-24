// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const RemovedCountSchema = z.object({
  removed_count: z.number(),
});

export type RemovedCount = z.infer<typeof RemovedCountSchema>;
