// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreExportSchema = z.object({
  id: z.string(),
  number: z.string(),
  type: z.string().nullable(),
  format: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  user_id: z.string().nullable(),
});

export type StoreExport = z.infer<typeof StoreExportSchema>;
