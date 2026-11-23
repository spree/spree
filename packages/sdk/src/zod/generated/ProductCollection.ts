// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductCollectionSchema = z.object({
  id: z.string(),
  product_id: z.string().nullable(),
  collection_id: z.string().nullable(),
});

export type ProductCollection = z.infer<typeof ProductCollectionSchema>;
