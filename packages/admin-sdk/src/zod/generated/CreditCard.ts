// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CreditCardSchema = z.object({
  id: z.string(),
  brand: z.string(),
  last4: z.string(),
  month: z.number(),
  year: z.number(),
  name: z.string().nullable(),
  default: z.boolean(),
  gateway_payment_profile_id: z.string().nullable(),
  customer_id: z.string().nullable(),
  payment_method_id: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
});

export type CreditCard = z.infer<typeof CreditCardSchema>;
