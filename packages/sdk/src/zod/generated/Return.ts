// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ReturnLineItemSchema } from './ReturnLineItem';
import { ReturnReasonSchema } from './ReturnReason';

export const ReturnSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  refund_total: z.string(),
  display_refund_total: z.string(),
  approved_at: z.string().nullable(),
  received_at: z.string().nullable(),
  refunded_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  reason: ReturnReasonSchema.optional(),
  return_line_items: z.array(ReturnLineItemSchema).optional(),
});

export type Return = z.infer<typeof ReturnSchema>;
