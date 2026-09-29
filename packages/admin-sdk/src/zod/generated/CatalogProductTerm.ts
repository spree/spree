// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CatalogProductTermSchema = z.object({
  id: z.string(),
  product_id: z.string(),
  product_name: z.string().nullable(),
  minimum_order_quantity: z.number().nullable(),
  order_multiple: z.number().nullable(),
  mixed: z.boolean(),
});

export type CatalogProductTerm = z.infer<typeof CatalogProductTermSchema>;
