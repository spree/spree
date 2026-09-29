// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StockTransferItemSchema = z.object({
  id: z.string(),
  quantity_shipped: z.number(),
  quantity_received: z.number(),
  quantity_rejected: z.number(),
  quantity_over: z.number(),
  outstanding: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  stock_transfer_id: z.string().nullable(),
  variant_id: z.string().nullable(),
  product_id: z.string().nullable(),
  variant_name: z.string().nullable(),
  variant_sku: z.string().nullable(),
  options_text: z.string().nullable(),
  thumbnail_url: z.string().nullable(),
});

export type StockTransferItem = z.infer<typeof StockTransferItemSchema>;
