// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StockTransferSchema = z.object({
  id: z.string(),
  number: z.string(),
  reference: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  source_location_id: z.string(),
  destination_location_id: z.string(),
});

export type StockTransfer = z.infer<typeof StockTransferSchema>;
