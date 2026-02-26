// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreStockTransferSchema = z.object({
  id: z.string(),
  number: z.string().nullable(),
  type: z.string().nullable(),
  reference: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  source_location_id: z.string().nullable(),
  destination_location_id: z.string().nullable(),
});

export type StoreStockTransfer = z.infer<typeof StoreStockTransferSchema>;
