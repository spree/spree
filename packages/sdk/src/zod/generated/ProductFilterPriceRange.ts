// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductFilterPriceRangeSchema = z.object({
  id: z.string(),
  type: z.literal('price_range'),
  min: z.string(),
  max: z.string(),
  currency: z.string(),
});

export type ProductFilterPriceRange = z.infer<typeof ProductFilterPriceRangeSchema>;
