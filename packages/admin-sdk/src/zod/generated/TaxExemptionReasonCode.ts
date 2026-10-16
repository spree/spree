// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TaxExemptionReasonCodeSchema = z.object({
  value: z.string(),
  label: z.string(),
});

export type TaxExemptionReasonCode = z.infer<typeof TaxExemptionReasonCodeSchema>;
