// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminCreditCardSchema = z.object({
  id: z.string(),
  cc_type: z.string(),
  last_digits: z.string(),
  month: z.number(),
  year: z.number(),
  name: z.string().nullable(),
  default: z.boolean(),
  gateway_payment_profile_id: z.string().nullable(),
  user_id: z.string().nullable(),
  payment_method_id: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type AdminCreditCard = z.infer<typeof AdminCreditCardSchema>;
