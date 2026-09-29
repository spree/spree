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
  fulfillment_status: z.string().nullable(),
  payment_status: z.string().nullable(),
  completed_at: z.string().nullable(),
  billing_address: AddressSchema.nullable(),
  shipping_address: AddressSchema.nullable(),
  orders: z.array(z.lazy(() => OrderSchema)),
  customer_id: z.string().nullable(),
  cart_id: z.string().nullable(),
  seller_count: z.number(),
  includes_first_party: z.boolean(),
  confirmation_delivered: z.boolean(),
  store_owner_notification_delivered: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  payments: z.array(z.lazy(() => PaymentSchema)),
});

export type OrderGroup = z.infer<typeof OrderGroupSchema>;
