// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TaxLineSchema = z.object({
  id: z.string(),
  label: z.string(),
  display_amount: z.string(),
  included: z.boolean(),
  amount: z.string(),
  tax_rate_id: z.string(),
});

export type TaxLine = z.infer<typeof TaxLineSchema>;
