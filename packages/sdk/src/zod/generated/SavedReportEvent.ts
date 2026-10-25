// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SavedReportEventSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  query: z.record(z.string(), z.unknown()),
  seeded: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  user_id: z.string().nullable(),
});

export type SavedReportEvent = z.infer<typeof SavedReportEventSchema>;
