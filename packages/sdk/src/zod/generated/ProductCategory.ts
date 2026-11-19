// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductCategorySchema = z.object({
  id: z.string(),
  product_id: z.string().nullable(),
  category_id: z.string().nullable(),
});

export type ProductCategory = z.infer<typeof ProductCategorySchema>;
