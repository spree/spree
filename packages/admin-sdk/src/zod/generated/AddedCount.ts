// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AddedCountSchema = z.object({
  added_count: z.number(),
});

export type AddedCount = z.infer<typeof AddedCountSchema>;
