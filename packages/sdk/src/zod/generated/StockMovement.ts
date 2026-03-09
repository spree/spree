// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StockMovementSchema = z.object({
  id: z.string(),
  quantity: z.number(),
  action: z.string().nullable(),
  originator_type: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  originator_id: z.string().nullable(),
  stock_item_id: z.string().nullable(),
});

export type StockMovement = z.infer<typeof StockMovementSchema>;
