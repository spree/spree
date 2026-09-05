// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductFilterAvailabilityOptionSchema = z.object({
  id: z.string(),
  count: z.number(),
});

export type ProductFilterAvailabilityOption = z.infer<typeof ProductFilterAvailabilityOptionSchema>;
