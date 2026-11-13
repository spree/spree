// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ProductSchema } from './Product';

export const CollectionExclusionSchema = z.object({
  id: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  collection_id: z.string(),
  product_id: z.string(),
  product: ProductSchema.optional(),
});

export type CollectionExclusion = z.infer<typeof CollectionExclusionSchema>;
