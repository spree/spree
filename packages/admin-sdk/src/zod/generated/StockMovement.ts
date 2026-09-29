// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StockMovementSchema = z.object({
  id: z.string(),
  quantity: z.number(),
  kind: z.string().nullable(),
  reason: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  stock_level_id: z.string().nullable(),
  stock_location_id: z.string().nullable(),
  stock_location_name: z.string().nullable(),
  variant_id: z.string().nullable(),
  variant_name: z.string().nullable(),
  variant_sku: z.string().nullable(),
  order_id: z.string().nullable(),
  fulfillment_id: z.string().nullable(),
  return_id: z.string().nullable(),
  exchange_id: z.string().nullable(),
  stock_transfer_id: z.string().nullable(),
  stock_receipt_id: z.string().nullable(),
  purchase_order_id: z.string().nullable(),
  order_number: z.string().nullable(),
  return_number: z.string().nullable(),
  exchange_number: z.string().nullable(),
  stock_transfer_number: z.string().nullable(),
  purchase_order_number: z.string().nullable(),
  unit_cost: z.string().nullable(),
  display_unit_cost: z.string().nullable(),
});

export type StockMovement = z.infer<typeof StockMovementSchema>;
