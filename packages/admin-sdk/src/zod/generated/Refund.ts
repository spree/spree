// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Refund from '../../types/generated/Refund';
import { ActorSchema } from './Actor';
import { PaymentSchema } from './Payment';

export const RefundSchema = z.object({
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
  tax_amount: z.string(),
  refunder_id: z.string().nullable(),
  refunder_type: z.string().nullable(),
  refunder: ActorSchema.optional(),
  get payment() { return PaymentSchema.optional(); },
}) as unknown as z.ZodObject<{
  id: z.ZodType<Refund['id']>;
  transaction_id: z.ZodType<Refund['transaction_id']>;
  amount: z.ZodType<Refund['amount']>;
  payment_id: z.ZodType<Refund['payment_id']>;
  refund_reason_id: z.ZodType<Refund['refund_reason_id']>;
  originator_id: z.ZodType<Refund['originator_id']>;
  originator_type: z.ZodType<Refund['originator_type']>;
  metadata: z.ZodType<Refund['metadata']>;
  created_at: z.ZodType<Refund['created_at']>;
  updated_at: z.ZodType<Refund['updated_at']>;
  tax_amount: z.ZodType<Refund['tax_amount']>;
  refunder_id: z.ZodType<Refund['refunder_id']>;
  refunder_type: z.ZodType<Refund['refunder_type']>;
  refunder: z.ZodOptional<z.ZodType<Exclude<Refund['refunder'], undefined>>>;
  payment: z.ZodOptional<z.ZodType<Exclude<Refund['payment'], undefined>>>;
}>;

export type { Refund };
