// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ConsentRecordSchema = z.object({
  id: z.string(),
  purpose: z.string(),
  source: z.string(),
  accepted: z.boolean(),
  email: z.string().nullable(),
  ip_address: z.string().nullable(),
  created_at: z.string(),
  recorded_at: z.string().nullable(),
  documents: z.array(z.record(z.string(), z.unknown())),
});

export type ConsentRecord = z.infer<typeof ConsentRecordSchema>;
