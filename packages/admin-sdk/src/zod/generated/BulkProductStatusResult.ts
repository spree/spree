// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const BulkProductStatusResultSchema = z.object({
  product_count: z.number(),
  status: z.string(),
  skipped_in_review_count: z.number().optional(),
});

export type BulkProductStatusResult = z.infer<typeof BulkProductStatusResultSchema>;
