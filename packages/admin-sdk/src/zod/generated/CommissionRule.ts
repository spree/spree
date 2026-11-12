// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CategorySchema } from './Category';
import { SellerSchema } from './Seller';

export const CommissionRuleSchema = z.object({
  id: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  type: z.string(),
  commission_rate_id: z.string(),
  preferences: z.record(z.string(), z.unknown()),
  product_ids: z.array(z.string()).nullable(),
  seller_ids: z.array(z.string()).nullable(),
  category_ids: z.array(z.string()).nullable(),
  sellers: z.array(SellerSchema).optional(),
  get categories() { return z.array(CategorySchema).optional(); },
});

export type CommissionRule = z.infer<typeof CommissionRuleSchema>;
