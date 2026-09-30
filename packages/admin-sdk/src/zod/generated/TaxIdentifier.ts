// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TaxIdentifierSchema = z.object({
  id: z.string(),
  kind: z.string(),
  value: z.string(),
  validation_status: z.string().nullable(),
  validation_evidence: z.record(z.string(), z.unknown()).nullable(),
  source: z.string().nullable(),
  validated_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  validatable: z.boolean(),
  customer_id: z.string().nullable(),
  cart_id: z.string().nullable(),
  order_id: z.string().nullable(),
});

export type TaxIdentifier = z.infer<typeof TaxIdentifierSchema>;
