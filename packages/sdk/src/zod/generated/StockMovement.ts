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
});

export type StockMovement = z.infer<typeof StockMovementSchema>;
