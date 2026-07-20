// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ProductFilterSortOptionSchema } from './ProductFilterSortOption';

export const ProductFiltersSchema = z.object({
  id: z.string(),
  default_sort: z.string(),
  total_count: z.number(),
  filters: z.array(z.any()),
  sort_options: z.array(ProductFilterSortOptionSchema),
});

export type ProductFilters = z.infer<typeof ProductFiltersSchema>;
