// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreStockItemSchema = z.object({
  id: z.string(),
  count_on_hand: z.number(),
  backorderable: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  stock_location_id: z.string().nullable(),
  variant_id: z.string().nullable(),
});

export type StoreStockItem = z.infer<typeof StoreStockItemSchema>;
