// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { OrderSchema } from './Order';
import { PaymentSchema } from './Payment';

export const OrderGroupSchema = z.object({
  id: z.string(),
  number: z.string(),
  email: z.string().nullable(),
  currency: z.string(),
  total: z.string().nullable(),
  display_total: z.string().nullable(),
  item_total: z.string().nullable(),
  display_item_total: z.string().nullable(),
  delivery_total: z.string().nullable(),
  display_delivery_total: z.string().nullable(),
  discount_total: z.string().nullable(),
  display_discount_total: z.string().nullable(),
  tax_total: z.string().nullable(),
  display_tax_total: z.string().nullable(),
  included_tax_total: z.string().nullable(),
  display_included_tax_total: z.string().nullable(),
  additional_tax_total: z.string().nullable(),
  display_additional_tax_total: z.string().nullable(),
  fee_total: z.string().nullable(),
  display_fee_total: z.string().nullable(),
  gift_card_total: z.string().nullable(),
  display_gift_card_total: z.string().nullable(),
  amount_due: z.string().nullable(),
  display_amount_due: z.string().nullable(),
  store_credit_total: z.string().nullable(),
  display_store_credit_total: z.string().nullable(),
  covered_by_store_credit: z.boolean(),
  fulfillment_status: z.string().nullable(),
  payment_status: z.string().nullable(),
  completed_at: z.string().nullable(),
  billing_address: AddressSchema.nullable(),
  shipping_address: AddressSchema.nullable(),
  payments: z.array(PaymentSchema),
  orders: z.array(OrderSchema),
});

export type OrderGroup = z.infer<typeof OrderGroupSchema>;
