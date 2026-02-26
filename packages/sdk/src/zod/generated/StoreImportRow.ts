// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreImportRowSchema = z.object({
  id: z.string(),
  row_number: z.number(),
  status: z.string(),
  validation_errors: z.any(),
  item_type: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  import_id: z.string().nullable(),
  item_id: z.string().nullable(),
});

export type StoreImportRow = z.infer<typeof StoreImportRowSchema>;
