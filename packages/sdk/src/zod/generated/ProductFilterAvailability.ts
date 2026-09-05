// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ProductFilterAvailabilityOptionSchema } from './ProductFilterAvailabilityOption';

export const ProductFilterAvailabilitySchema = z.object({
  id: z.string(),
  type: z.any(),
  options: z.array(ProductFilterAvailabilityOptionSchema),
});

export type ProductFilterAvailability = z.infer<typeof ProductFilterAvailabilitySchema>;
