// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailLineItemSchema } from './EmailLineItem';

export const EmailReturnSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  refund_total: z.string().nullable(),
  display_refund_total: z.string().nullable(),
  refund_tax_total: z.string().nullable(),
  display_refund_tax_total: z.string().nullable(),
  approved_at: z.string().nullable(),
  received_at: z.string().nullable(),
  refunded_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  refunded_total: z.string(),
  display_refunded_total: z.string(),
  returned_items: z.array(EmailLineItemSchema),
});

export type EmailReturn = z.infer<typeof EmailReturnSchema>;
