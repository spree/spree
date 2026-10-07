// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StockReceiptItemSchema = z.object({
  id: z.string(),
  quantity_accepted: z.number(),
  quantity_rejected: z.number(),
  rejection_reason: z.string().nullable(),
  notes: z.string().nullable(),
  line_type: z.string(),
  line_id: z.string().nullable(),
  variant_id: z.string().nullable(),
  product_id: z.string().nullable(),
  variant_name: z.string().nullable(),
  variant_sku: z.string().nullable(),
  thumbnail_url: z.string().nullable(),
});

export type StockReceiptItem = z.infer<typeof StockReceiptItemSchema>;
