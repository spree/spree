// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreVariantSchema } from './StoreVariant';

export const StoreWishedItemSchema = z.object({
  id: z.string(),
  variant_id: z.string(),
  wishlist_id: z.string(),
  quantity: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  variant: StoreVariantSchema,
});

export type StoreWishedItem = z.infer<typeof StoreWishedItemSchema>;
