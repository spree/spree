// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StockReservationSchema = z.object({
  id: z.string(),
  stock_level_id: z.string(),
  line_item_id: z.string(),
  order_id: z.string(),
  variant_id: z.string().nullable(),
  stock_location_id: z.string().nullable(),
  quantity: z.number(),
  expires_at: z.string(),
  active: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type StockReservation = z.infer<typeof StockReservationSchema>;
