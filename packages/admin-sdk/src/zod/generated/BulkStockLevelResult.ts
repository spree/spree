// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const BulkStockLevelResultSchema = z.object({
  stock_level_count: z.number(),
});

export type BulkStockLevelResult = z.infer<typeof BulkStockLevelResultSchema>;
