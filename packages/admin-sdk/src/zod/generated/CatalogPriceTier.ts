// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CatalogPriceTierSchema = z.object({
  min_quantity: z.number(),
  display_amount: z.string(),
  amount: z.string(),
});

export type CatalogPriceTier = z.infer<typeof CatalogPriceTierSchema>;
