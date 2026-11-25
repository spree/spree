// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const BulkProductResultSchema = z.object({
  product_count: z.number(),
  skipped_count: z.number().optional(),
});

export type BulkProductResult = z.infer<typeof BulkProductResultSchema>;
