// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { VariantSchema } from './Variant';

export const WishedItemSchema = z.object({
  id: z.string(),
  variant_id: z.string(),
  wishlist_id: z.string(),
  quantity: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  variant: VariantSchema,
});

export type WishedItem = z.infer<typeof WishedItemSchema>;
