// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const BulkProductCategoriesResultSchema = z.object({
  product_count: z.number(),
  category_count: z.number(),
});

export type BulkProductCategoriesResult = z.infer<typeof BulkProductCategoriesResultSchema>;
