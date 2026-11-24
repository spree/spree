// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const BulkProductTagsResultSchema = z.object({
  product_count: z.number(),
  tag_count: z.number(),
});

export type BulkProductTagsResult = z.infer<typeof BulkProductTagsResultSchema>;
