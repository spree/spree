// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { FulfillmentSchema } from './Fulfillment';
import { OrderLineItemSchema } from './OrderLineItem';
import { PaymentSplitSchema } from './PaymentSplit';

export const OrderSchema = z.object({
  id: z.string(),
  number: z.string(),
  customer_note: z.string().nullable(),
  currency: z.string(),
  total_quantity: z.number(),
  status: z.string(),
  fulfillment_status: z.string().nullable(),
  payment_status: z.string().nullable(),
  completed_at: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  internal_note: z.string().nullable(),
  internal_note_html: z.string().nullable(),
  item_total: z.string().nullable(),
  delivery_total: z.string().nullable(),
  discount_total: z.string().nullable(),
  adjustment_total: z.string().nullable(),
  included_tax_total: z.string().nullable(),
  additional_tax_total: z.string().nullable(),
  tax_total: z.string().nullable(),
  total: z.string().nullable(),
  payment_total: z.string().nullable(),
  amount_due: z.string().nullable(),
  commission_amount_total: z.string().nullable(),
  commission_tax_total: z.string().nullable(),
  commission_total: z.string().nullable(),
  canceled_at: z.string().nullable(),
  cancel_reason_name: z.string().nullable(),
  cancel_note: z.string().nullable(),
  items: z.array(OrderLineItemSchema),
  payment_splits: z.array(PaymentSplitSchema).optional(),
  fulfillments: z.array(FulfillmentSchema),
  shipping_address: AddressSchema,
  billing_address: AddressSchema,
});

export type Order = z.infer<typeof OrderSchema>;
