// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const BulkProductCollectionsResultSchema = z.object({
  product_count: z.number(),
  collection_count: z.number(),
});

export type BulkProductCollectionsResult = z.infer<typeof BulkProductCollectionsResultSchema>;
