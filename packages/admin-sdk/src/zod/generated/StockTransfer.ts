// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StockLocationSchema } from './StockLocation';
import { StockReceiptSchema } from './StockReceipt';
import { StockTransferItemSchema } from './StockTransferItem';

export const StockTransferSchema = z.object({
  id: z.string(),
  number: z.string(),
  reference: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  source_location_id: z.string(),
  destination_location_id: z.string(),
  status: z.string(),
  notes: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  close_reason: z.string().nullable(),
  items_count: z.number(),
  quantity_received_total: z.number(),
  quantity_rejected_total: z.number(),
  shipped_at: z.string().nullable(),
  received_at: z.string().nullable(),
  closed_short_at: z.string().nullable(),
  deleted_at: z.string().nullable(),
  closed_short: z.boolean(),
  quantity_shipped_total: z.number(),
  editable: z.boolean(),
  items: z.array(StockTransferItemSchema).optional(),
  stock_receipts: z.array(StockReceiptSchema).optional(),
  source_location: StockLocationSchema.optional(),
  destination_location: StockLocationSchema.optional(),
});

export type StockTransfer = z.infer<typeof StockTransferSchema>;
