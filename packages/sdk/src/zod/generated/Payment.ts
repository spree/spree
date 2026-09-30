// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CreditCardSchema } from './CreditCard';
import { PaymentMethodSchema } from './PaymentMethod';
import { PaymentSourceSchema } from './PaymentSource';
import { StoreCreditSchema } from './StoreCredit';

export const PaymentSchema = z.object({
  id: z.string(),
  payment_method_id: z.string(),
  response_code: z.string().nullable(),
  number: z.string(),
  status: z.string(),
  amount: z.string().nullable(),
  display_amount: z.string().nullable(),
  source_type: z.string().nullable(),
  source_id: z.string().nullable(),
  source: z.union([CreditCardSchema, StoreCreditSchema, PaymentSourceSchema]).nullable(),
  payment_method: PaymentMethodSchema,
});

export type Payment = z.infer<typeof PaymentSchema>;
