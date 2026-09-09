// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DataRequestEventSchema = z.object({
  id: z.string(),
  number: z.string(),
  kind: z.string(),
  status: z.string(),
  requested_at: z.string().nullable(),
  completed_at: z.string().nullable(),
});

export type DataRequestEvent = z.infer<typeof DataRequestEventSchema>;
