// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StorePostCategorySchema = z.object({
  id: z.string(),
  title: z.string(),
  slug: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type StorePostCategory = z.infer<typeof StorePostCategorySchema>;
