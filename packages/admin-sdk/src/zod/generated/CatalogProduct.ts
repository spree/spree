// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CatalogPriceSchema } from './CatalogPrice';
import { CatalogProductTermSchema } from './CatalogProductTerm';

export const CatalogProductSchema = z.object({
  id: z.string(),
  name: z.string(),
  thumbnail_url: z.string().nullable(),
  quantity_rule: CatalogProductTermSchema.nullable().optional(),
  catalog_variants: z.array(CatalogPriceSchema).optional(),
});

export type CatalogProduct = z.infer<typeof CatalogProductSchema>;
