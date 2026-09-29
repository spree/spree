// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ProductFilterAvailabilitySchema } from './ProductFilterAvailability';
import { ProductFilterCategorySchema } from './ProductFilterCategory';
import { ProductFilterOptionSchema } from './ProductFilterOption';
import { ProductFilterPriceRangeSchema } from './ProductFilterPriceRange';
import { ProductFilterSortOptionSchema } from './ProductFilterSortOption';

export const ProductFiltersSchema = z.object({
  id: z.string(),
  default_sort: z.string(),
  total_count: z.number(),
  filters: z.array(z.union([ProductFilterPriceRangeSchema, ProductFilterAvailabilitySchema, ProductFilterOptionSchema, ProductFilterCategorySchema])),
  sort_options: z.array(ProductFilterSortOptionSchema),
});

export type ProductFilters = z.infer<typeof ProductFiltersSchema>;
