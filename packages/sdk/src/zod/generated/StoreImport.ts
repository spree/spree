// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreImportSchema = z.object({
  id: z.string(),
  number: z.string(),
  type: z.string().nullable(),
  rows_count: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  status: z.string(),
  owner_type: z.string().nullable(),
  owner_id: z.string().nullable(),
  user_id: z.string().nullable(),
});

export type StoreImport = z.infer<typeof StoreImportSchema>;
