// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ProductFilterCategoryOptionSchema } from './ProductFilterCategoryOption';

export const ProductFilterCategorySchema = z.object({
  id: z.string(),
  type: z.any(),
  options: z.array(ProductFilterCategoryOptionSchema),
});

export type ProductFilterCategory = z.infer<typeof ProductFilterCategorySchema>;
