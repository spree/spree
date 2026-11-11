// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailLineItemSchema } from './EmailLineItem';
import { EmailParcelItemSchema } from './EmailParcelItem';
import { EmailStockLocationSchema } from './EmailStockLocation';

export const EmailReturnSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  cancelable: z.boolean(),
  label_available: z.boolean(),
  tracking: z.string().nullable(),
  tracking_url: z.string().nullable(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  refund_total: z.string().nullable(),
  refund_tax_total: z.string().nullable(),
  approved_at: z.string().nullable(),
  received_at: z.string().nullable(),
  refunded_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  refunded_total: z.string(),
  returned_items: z.array(EmailLineItemSchema),
  items: z.array(EmailParcelItemSchema),
  stock_location: EmailStockLocationSchema,
  memo: z.string().nullable(),
  reason_name: z.string().nullable(),
});

export type EmailReturn = z.infer<typeof EmailReturnSchema>;
