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
});

export type CreditCard = z.infer<typeof CreditCardSchema>;
