// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TaxLineSchema = z.object({
  id: z.string(),
  label: z.string(),
  included: z.boolean(),
  credit: z.boolean(),
  rate: z.string(),
  tax_rate_id: z.string().nullable(),
  line_item_id: z.string().nullable(),
  fulfillment_id: z.string().nullable(),
  fee_id: z.string().nullable(),
  return_line_item_id: z.string().nullable(),
  claim_line_item_id: z.string().nullable(),
  exchange_line_item_id: z.string().nullable(),
  amount: z.string(),
  display_amount: z.string(),
  provider_id: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  taxability_reason: z.string().nullable(),
  country_code: z.string().nullable(),
  state_code: z.string().nullable(),
  data: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  original_tax_line_id: z.string().nullable(),
});

export type TaxLine = z.infer<typeof TaxLineSchema>;
