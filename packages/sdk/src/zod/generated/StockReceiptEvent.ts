// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StockReceiptEventSchema = z.object({
  id: z.string(),
  number: z.string(),
  quantity_accepted_total: z.number(),
  quantity_rejected_total: z.number(),
  received_at: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  receivable_type: z.string(),
  receivable_id: z.string(),
});

export type StockReceiptEvent = z.infer<typeof StockReceiptEventSchema>;
