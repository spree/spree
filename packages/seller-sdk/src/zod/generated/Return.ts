// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ReasonSchema } from './Reason';
import { ReturnLineItemSchema } from './ReturnLineItem';

export const ReturnSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  refund_total: z.string(),
  display_refund_total: z.string(),
  refund_tax_total: z.string(),
  display_refund_tax_total: z.string(),
  approved_at: z.string().nullable(),
  received_at: z.string().nullable(),
  refunded_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  reason: ReasonSchema.optional(),
  return_line_items: z.array(ReturnLineItemSchema).optional(),
  memo: z.string().nullable(),
  stock_location_id: z.string().nullable(),
  refunded_total: z.string(),
  refundable_total: z.string(),
  display_refunded_total: z.string(),
});

export type Return = z.infer<typeof ReturnSchema>;
