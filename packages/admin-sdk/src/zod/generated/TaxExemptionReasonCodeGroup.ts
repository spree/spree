// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { TaxExemptionReasonCodeSchema } from './TaxExemptionReasonCode';

export const TaxExemptionReasonCodeGroupSchema = z.object({
  provider: z.string().nullable(),
  reason_codes: z.array(TaxExemptionReasonCodeSchema),
});

export type TaxExemptionReasonCodeGroup = z.infer<typeof TaxExemptionReasonCodeGroupSchema>;
