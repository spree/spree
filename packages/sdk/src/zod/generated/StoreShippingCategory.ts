// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreShippingCategorySchema = z.object({
  id: z.string(),
  name: z.string(),
});

export type StoreShippingCategory = z.infer<typeof StoreShippingCategorySchema>;
