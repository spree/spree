// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TaxLineSchema = z.object({
  id: z.string(),
  label: z.string(),
  included: z.boolean(),
  rate: z.string(),
  tax_rate_id: z.string().nullable(),
  line_item_id: z.string().nullable(),
  fulfillment_id: z.string().nullable(),
  fee_id: z.string().nullable(),
  amount: z.string().nullable(),
  display_amount: z.string().nullable(),
});

export type TaxLine = z.infer<typeof TaxLineSchema>;
