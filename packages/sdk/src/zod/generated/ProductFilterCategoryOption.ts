// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductFilterCategoryOptionSchema = z.object({
  id: z.string(),
  name: z.string(),
  permalink: z.string(),
  count: z.number(),
});

export type ProductFilterCategoryOption = z.infer<typeof ProductFilterCategoryOptionSchema>;
