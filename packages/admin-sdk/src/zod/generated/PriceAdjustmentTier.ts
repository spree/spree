// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PriceAdjustmentTierSchema = z.object({
  id: z.string(),
  min_quantity: z.number(),
  percentage: z.string(),
});

export type PriceAdjustmentTier = z.infer<typeof PriceAdjustmentTierSchema>;
