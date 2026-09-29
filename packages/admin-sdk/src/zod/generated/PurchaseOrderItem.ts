// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PurchaseOrderItemSchema = z.object({
  id: z.string(),
  quantity_ordered: z.number(),
  quantity_received: z.number(),
  quantity_rejected: z.number(),
  quantity_over: z.number(),
  outstanding: z.number(),
  currency: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  unit_cost: z.string(),
  total_cost: z.string(),
  display_unit_cost: z.string(),
  display_total_cost: z.string(),
  purchase_order_id: z.string().nullable(),
  variant_id: z.string().nullable(),
  product_id: z.string().nullable(),
  variant_name: z.string().nullable(),
  variant_sku: z.string().nullable(),
  options_text: z.string().nullable(),
  thumbnail_url: z.string().nullable(),
});

export type PurchaseOrderItem = z.infer<typeof PurchaseOrderItemSchema>;
