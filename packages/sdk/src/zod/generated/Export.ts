// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ExportSchema = z.object({
  id: z.string(),
  number: z.string(),
  format: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  type: z.string().nullable(),
  user_id: z.string().nullable(),
});

export type Export = z.infer<typeof ExportSchema>;
