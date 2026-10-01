// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { PriceAdjustmentTierSchema } from './PriceAdjustmentTier';
import { PriceRuleSchema } from './PriceRule';

export const PriceListSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  status: z.string(),
  position: z.number(),
  match_policy: z.string(),
  adjust_compare_at: z.boolean(),
  starts_at: z.string().nullable(),
  ends_at: z.string().nullable(),
  deleted_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  price_adjustment_percentage: z.string().nullable(),
  automatic_pricing: z.boolean(),
  currently_active: z.boolean(),
  products_count: z.number(),
  prices_count: z.number(),
  price_adjustment_tiers: z.array(PriceAdjustmentTierSchema),
  price_rules: z.array(PriceRuleSchema).optional(),
});

export type PriceList = z.infer<typeof PriceListSchema>;
