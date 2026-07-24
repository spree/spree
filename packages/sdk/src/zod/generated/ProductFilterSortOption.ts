// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductFilterSortOptionSchema = z.object({
  id: z.string(),
  label: z.string().nullable(),
});

export type ProductFilterSortOption = z.infer<typeof ProductFilterSortOptionSchema>;
