// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StockLevelSchema = z.object({
  id: z.string(),
  count_on_hand: z.number(),
  backorderable: z.boolean(),
  stock_location_id: z.string().nullable(),
  variant_id: z.string().nullable(),
});

export type StockLevel = z.infer<typeof StockLevelSchema>;
