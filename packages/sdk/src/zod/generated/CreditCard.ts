// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CreditCardSchema = z.object({
  id: z.string(),
  cc_type: z.string(),
  last_digits: z.string(),
  month: z.number(),
  year: z.number(),
  name: z.string().nullable(),
  default: z.boolean(),
  gateway_payment_profile_id: z.string().nullable(),
});

export type CreditCard = z.infer<typeof CreditCardSchema>;
