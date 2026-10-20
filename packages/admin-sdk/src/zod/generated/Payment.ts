// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Payment from '../../types/generated/Payment';
import { CreditCardSchema } from './CreditCard';
import { OrderSchema } from './Order';
import { PaymentCaptureEventSchema } from './PaymentCaptureEvent';
import { PaymentMethodSchema } from './PaymentMethod';
import { PaymentSourceSchema } from './PaymentSource';
import { PaymentSplitSchema } from './PaymentSplit';
import { RefundSchema } from './Refund';
import { StoreCreditSchema } from './StoreCredit';

export const PaymentSchema = z.object({
  id: z.string(),
  payment_method_id: z.string(),
  response_code: z.string().nullable(),
  number: z.string(),
  status: z.string(),
  amount: z.string(),
  source_type: z.string().nullable(),
  source_id: z.string().nullable(),
  get source() { return z.union([CreditCardSchema, StoreCreditSchema, PaymentSourceSchema]).nullable(); },
  payment_method: PaymentMethodSchema.optional(),
  metadata: z.record(z.string(), z.unknown()),
  avs_response: z.string().nullable(),
  cvv_response_code: z.string().nullable(),
  cvv_response_message: z.string().nullable(),
  gateway_dashboard_payment_url: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  avs_risky: z.boolean(),
  cvv_risky: z.boolean(),
  captured_amount: z.string(),
  order_id: z.string().nullable(),
  capture_events: z.array(PaymentCaptureEventSchema).optional(),
  get order() { return OrderSchema.optional(); },
  get refunds() { return z.array(RefundSchema).optional(); },
  payment_splits: z.array(PaymentSplitSchema).optional(),
}) as unknown as z.ZodObject<{
  id: z.ZodType<Payment['id']>;
  payment_method_id: z.ZodType<Payment['payment_method_id']>;
  response_code: z.ZodType<Payment['response_code']>;
  number: z.ZodType<Payment['number']>;
  status: z.ZodType<Payment['status']>;
  amount: z.ZodType<Payment['amount']>;
  source_type: z.ZodType<Payment['source_type']>;
  source_id: z.ZodType<Payment['source_id']>;
  source: z.ZodType<Payment['source']>;
  payment_method: z.ZodOptional<z.ZodType<Exclude<Payment['payment_method'], undefined>>>;
  metadata: z.ZodType<Payment['metadata']>;
  avs_response: z.ZodType<Payment['avs_response']>;
  cvv_response_code: z.ZodType<Payment['cvv_response_code']>;
  cvv_response_message: z.ZodType<Payment['cvv_response_message']>;
  gateway_dashboard_payment_url: z.ZodType<Payment['gateway_dashboard_payment_url']>;
  created_at: z.ZodType<Payment['created_at']>;
  updated_at: z.ZodType<Payment['updated_at']>;
  avs_risky: z.ZodType<Payment['avs_risky']>;
  cvv_risky: z.ZodType<Payment['cvv_risky']>;
  captured_amount: z.ZodType<Payment['captured_amount']>;
  order_id: z.ZodType<Payment['order_id']>;
  capture_events: z.ZodOptional<z.ZodType<Exclude<Payment['capture_events'], undefined>>>;
  order: z.ZodOptional<z.ZodType<Exclude<Payment['order'], undefined>>>;
  refunds: z.ZodOptional<z.ZodType<Exclude<Payment['refunds'], undefined>>>;
  payment_splits: z.ZodOptional<z.ZodType<Exclude<Payment['payment_splits'], undefined>>>;
}>;

export type { Payment };
