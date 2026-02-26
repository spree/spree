// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StorePostSchema = z.object({
  id: z.string(),
  title: z.string(),
  slug: z.string(),
  meta_title: z.string().nullable(),
  meta_description: z.string().nullable(),
  published_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  author_id: z.string().nullable(),
  post_category_id: z.string().nullable(),
});

export type StorePost = z.infer<typeof StorePostSchema>;
