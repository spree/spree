// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CatalogPriceSchema } from './CatalogPrice';

export const PriceListProductSchema = z.object({
  id: z.string(),
  name: z.string(),
  thumbnail_url: z.string().nullable(),
  price_list_variants: z.array(CatalogPriceSchema).optional(),
});

export type PriceListProduct = z.infer<typeof PriceListProductSchema>;
