// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ActorSchema } from './Actor';
import { PaymentSchema } from './Payment';

export const RefundSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  transaction_id: z.string().nullable(),
  amount: z.string().nullable(),
  payment_id: z.string().nullable(),
  refund_reason_id: z.string().nullable(),
  originator_id: z.string().nullable(),
  originator_type: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  refunder_id: z.string().nullable(),
  refunder_type: z.string().nullable(),
  refunder: ActorSchema.optional(),
  payment: z.lazy(() => PaymentSchema).optional(),
});

export type Refund = z.infer<typeof RefundSchema>;
