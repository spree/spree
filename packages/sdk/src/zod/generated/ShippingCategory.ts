// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ShippingCategorySchema = z.object({
  id: z.string(),
  name: z.string(),
});

export type ShippingCategory = z.infer<typeof ShippingCategorySchema>;
