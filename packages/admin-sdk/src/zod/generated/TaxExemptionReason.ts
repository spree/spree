// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TaxExemptionReasonSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string(),
  active: z.boolean(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  can_be_deleted: z.boolean(),
});

export type TaxExemptionReason = z.infer<typeof TaxExemptionReasonSchema>;
