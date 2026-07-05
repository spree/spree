// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { VariantSchema } from './Variant';

export const WishlistItemSchema = z.object({
  id: z.string(),
  variant_id: z.string(),
  wishlist_id: z.string(),
  quantity: z.number(),
  variant: VariantSchema,
});

export type WishlistItem = z.infer<typeof WishlistItemSchema>;
