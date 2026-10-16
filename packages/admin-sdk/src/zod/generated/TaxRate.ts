// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TaxRateSchema = z.object({
  id: z.string(),
  name: z.string(),
  included_in_price: z.boolean(),
  show_rate_in_label: z.boolean(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  deleted_at: z.string().nullable(),
  rate: z.string().nullable(),
  rate_percent: z.string().nullable(),
  tax_category_id: z.string().nullable(),
  store_id: z.string().nullable(),
  country_code: z.string().nullable(),
  state_code: z.string().nullable(),
});

export type TaxRate = z.infer<typeof TaxRateSchema>;
