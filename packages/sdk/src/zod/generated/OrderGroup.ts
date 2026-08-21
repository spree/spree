// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { OrderSchema } from './Order';

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
  orders: z.array(OrderSchema),
});

export type OrderGroup = z.infer<typeof OrderGroupSchema>;
