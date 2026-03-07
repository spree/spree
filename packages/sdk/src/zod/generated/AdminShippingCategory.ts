// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminShippingCategorySchema = z.object({
  id: z.string(),
  name: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type AdminShippingCategory = z.infer<typeof AdminShippingCategorySchema>;
