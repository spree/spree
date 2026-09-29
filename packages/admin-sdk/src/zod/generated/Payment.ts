// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CreditCardSchema } from './CreditCard';
import { OrderSchema } from './Order';
import { PaymentMethodSchema } from './PaymentMethod';
import { PaymentSourceSchema } from './PaymentSource';
import { PaymentSplitSchema } from './PaymentSplit';
import { RefundSchema } from './Refund';
import { StoreCreditSchema } from './StoreCredit';

export const PaymentSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  payment_method_id: z.string(),
  response_code: z.string().nullable(),
  number: z.string(),
  status: z.string(),
  amount: z.string(),
  display_amount: z.string(),
  source_type: z.string().nullable(),
  source_id: z.string().nullable(),
  source: z.union([CreditCardSchema, z.lazy(() => StoreCreditSchema), PaymentSourceSchema]).nullable(),
  payment_method: PaymentMethodSchema.optional(),
  metadata: z.record(z.string(), z.unknown()),
  avs_response: z.string().nullable(),
  cvv_response_code: z.string().nullable(),
  cvv_response_message: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  captured_amount: z.string(),
  order_id: z.string().nullable(),
  order: z.lazy(() => OrderSchema).optional(),
  refunds: z.array(z.lazy(() => RefundSchema)).optional(),
  payment_splits: z.array(PaymentSplitSchema).optional(),
});

export type Payment = z.infer<typeof PaymentSchema>;
