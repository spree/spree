// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductFilterPriceRangeSchema = z.object({
  id: z.string(),
  type: z.any(),
  min: z.number(),
  max: z.number(),
  currency: z.string(),
});

export type ProductFilterPriceRange = z.infer<typeof ProductFilterPriceRangeSchema>;
