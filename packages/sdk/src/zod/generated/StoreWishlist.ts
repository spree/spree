// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreWishedItemSchema } from './StoreWishedItem';

export const StoreWishlistSchema = z.object({
  id: z.string(),
  name: z.string(),
  token: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  is_default: z.boolean(),
  is_private: z.boolean(),
  items: z.array(StoreWishedItemSchema).optional(),
});

export type StoreWishlist = z.infer<typeof StoreWishlistSchema>;
