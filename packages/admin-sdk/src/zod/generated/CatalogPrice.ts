// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CatalogPriceTierSchema } from './CatalogPriceTier';

export const CatalogPriceSchema = z.object({
  id: z.string().nullable(),
  label: z.string().nullable(),
  sku: z.string().nullable(),
  currency: z.string(),
  source: z.string(),
  break_count: z.number(),
  amount: z.string(),
  tiers: z.array(CatalogPriceTierSchema),
});

export type CatalogPrice = z.infer<typeof CatalogPriceSchema>;
