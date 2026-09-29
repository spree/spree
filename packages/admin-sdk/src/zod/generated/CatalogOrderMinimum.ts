// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CatalogOrderMinimumSchema = z.object({
  id: z.string(),
  currency: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  amount: z.string(),
  display_amount: z.string(),
});

export type CatalogOrderMinimum = z.infer<typeof CatalogOrderMinimumSchema>;
