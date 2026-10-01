// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailPaymentMethodSchema } from './EmailPaymentMethod';

export const EmailPaymentSchema = z.object({
  id: z.string(),
  payment_method_id: z.string(),
  response_code: z.string().nullable(),
  number: z.string(),
  status: z.string(),
  amount: z.string().nullable(),
  display_amount: z.string().nullable(),
  source_type: z.string().nullable(),
  source_id: z.string().nullable(),
  source: z.record(z.string(), z.unknown()).nullable(),
  payment_method: EmailPaymentMethodSchema,
});

export type EmailPayment = z.infer<typeof EmailPaymentSchema>;
