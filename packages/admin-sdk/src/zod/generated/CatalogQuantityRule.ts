// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CatalogQuantityRuleSchema = z.object({
  id: z.string(),
  minimum_order_quantity: z.number().nullable(),
  order_multiple: z.number().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  variant_id: z.string().nullable(),
  variant_sku: z.string().nullable(),
  product_name: z.string().nullable(),
  options_text: z.string().nullable(),
});

export type CatalogQuantityRule = z.infer<typeof CatalogQuantityRuleSchema>;
