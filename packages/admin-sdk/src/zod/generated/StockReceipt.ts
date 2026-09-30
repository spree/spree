// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ActorSchema } from './Actor';
import { StockReceiptItemSchema } from './StockReceiptItem';

export const StockReceiptSchema = z.object({
  id: z.string(),
  number: z.string(),
  reference: z.string().nullable(),
  notes: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  quantity_accepted_total: z.number(),
  quantity_rejected_total: z.number(),
  received_at: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  receivable_type: z.string(),
  receivable_id: z.string(),
  received_by_id: z.string().nullable(),
  received_by_type: z.string().nullable(),
  received_by: ActorSchema.optional(),
  items_count: z.number(),
  items: z.array(StockReceiptItemSchema).optional(),
});

export type StockReceipt = z.infer<typeof StockReceiptSchema>;
