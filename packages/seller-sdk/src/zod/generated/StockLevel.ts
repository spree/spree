// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StockLocationSchema } from './StockLocation';

export const StockLevelSchema = z.object({
  id: z.string(),
  count_on_hand: z.number(),
  backorderable: z.boolean(),
  stock_location_id: z.string().nullable(),
  variant_id: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  allocated_count: z.number(),
  available_count: z.number(),
  stock_location: StockLocationSchema.optional(),
});

export type StockLevel = z.infer<typeof StockLevelSchema>;
