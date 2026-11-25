// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const BulkProductResultSchema = z.object({
  product_count: z.number(),
  status: z.string().optional(),
  skipped_in_review_count: z.number().optional(),
  category_count: z.number().optional(),
  collection_count: z.number().optional(),
  channel_count: z.number().optional(),
  removed: z.number().optional(),
  tag_count: z.number().optional(),
});

export type BulkProductResult = z.infer<typeof BulkProductResultSchema>;
