// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CommissionRateSchema } from './CommissionRate';

export const CommissionLineSchema = z.object({
  id: z.string(),
  kind: z.string(),
  currency: z.string(),
  taxability_reason: z.string().nullable(),
  country_code: z.string().nullable(),
  state_code: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  rate: z.string(),
  tax_rate: z.string(),
  amount: z.string(),
  tax_amount: z.string(),
  total: z.string(),
  display_amount: z.string(),
  display_tax_amount: z.string(),
  display_total: z.string(),
  order_id: z.string(),
  seller_id: z.string(),
  line_item_id: z.string().nullable(),
  fulfillment_id: z.string().nullable(),
  commission_rate_id: z.string().nullable(),
  seller_name: z.string().nullable(),
  commission_rate: CommissionRateSchema.optional(),
});

export type CommissionLine = z.infer<typeof CommissionLineSchema>;
