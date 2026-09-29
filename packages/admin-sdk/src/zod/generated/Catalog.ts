// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CatalogAssignmentSchema } from './CatalogAssignment';
import { CatalogOrderMinimumSchema } from './CatalogOrderMinimum';
import { PriceListSchema } from './PriceList';

export const CatalogSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  active: z.boolean(),
  position: z.number().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  minimum_order_quantity: z.number().nullable(),
  order_multiple: z.number().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  products_count: z.number(),
  pricing_strategy: z.string(),
  order_minimums: z.array(CatalogOrderMinimumSchema).optional(),
  price_list: PriceListSchema.optional(),
  assignments: z.array(CatalogAssignmentSchema).optional(),
});

export type Catalog = z.infer<typeof CatalogSchema>;
