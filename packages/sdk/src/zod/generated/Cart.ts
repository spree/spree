// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { DiscountSchema } from './Discount';
import { FulfillmentSchema } from './Fulfillment';
import { GiftCardSchema } from './GiftCard';
import { LineItemSchema } from './LineItem';
import { PaymentSchema } from './Payment';
import { PaymentMethodSchema } from './PaymentMethod';

export const CartSchema = z.object({
  id: z.string(),
  number: z.string(),
  token: z.string(),
  email: z.string().nullable(),
  customer_note: z.string().nullable(),
  currency: z.string(),
  locale: z.string().nullable(),
  total_quantity: z.number(),
  item_total: z.string(),
  display_item_total: z.string(),
  adjustment_total: z.string(),
  display_adjustment_total: z.string(),
  discount_total: z.string(),
  display_discount_total: z.string(),
  tax_total: z.string(),
  display_tax_total: z.string(),
  included_tax_total: z.string(),
  display_included_tax_total: z.string(),
  additional_tax_total: z.string(),
  display_additional_tax_total: z.string(),
  total: z.string(),
  display_total: z.string(),
  delivery_total: z.string(),
  display_delivery_total: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  store_credit_total: z.string(),
  display_store_credit_total: z.string(),
  gift_card_total: z.string(),
  display_gift_card_total: z.string(),
  covered_by_store_credit: z.boolean(),
  current_step: z.string(),
  completed_steps: z.array(z.string()),
  requirements: z.array(z.object({ step: z.string(), field: z.string(), message: z.string() })),
  shipping_eq_billing_address: z.boolean(),
  discounts: z.array(DiscountSchema),
  items: z.array(LineItemSchema),
  fulfillments: z.array(FulfillmentSchema),
  payments: z.array(PaymentSchema),
  billing_address: AddressSchema.nullable(),
  shipping_address: AddressSchema.nullable(),
  payment_methods: z.array(PaymentMethodSchema),
  gift_card: GiftCardSchema.nullable(),
});

export type Cart = z.infer<typeof CartSchema>;
