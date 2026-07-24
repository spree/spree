// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { DiscountSchema } from './Discount';
import { FulfillmentSchema } from './Fulfillment';
import { GiftCardSchema } from './GiftCard';
import { LineItemSchema } from './LineItem';
import { MarketSchema } from './Market';
import { PaymentSchema } from './Payment';

export const OrderSchema = z.object({
  id: z.string(),
  market_id: z.string().nullable(),
  channel_id: z.string().nullable(),
  number: z.string(),
  email: z.string(),
  customer_note: z.string().nullable(),
  currency: z.string(),
  locale: z.string().nullable(),
  total_quantity: z.number(),
  fulfillment_status: z.string().nullable(),
  payment_status: z.string().nullable(),
  completed_at: z.string().nullable(),
  item_total: z.string().nullable(),
  display_item_total: z.string().nullable(),
  adjustment_total: z.string().nullable(),
  display_adjustment_total: z.string().nullable(),
  discount_total: z.string().nullable(),
  display_discount_total: z.string().nullable(),
  fee_total: z.string().nullable(),
  display_fee_total: z.string().nullable(),
  tax_total: z.string().nullable(),
  display_tax_total: z.string().nullable(),
  included_tax_total: z.string().nullable(),
  display_included_tax_total: z.string().nullable(),
  additional_tax_total: z.string().nullable(),
  display_additional_tax_total: z.string().nullable(),
  total: z.string().nullable(),
  display_total: z.string().nullable(),
  gift_card_total: z.string().nullable(),
  display_gift_card_total: z.string().nullable(),
  amount_due: z.string().nullable(),
  display_amount_due: z.string().nullable(),
  delivery_total: z.string().nullable(),
  display_delivery_total: z.string().nullable(),
  store_credit_total: z.string().nullable(),
  display_store_credit_total: z.string().nullable(),
  covered_by_store_credit: z.boolean(),
  discounts: z.array(DiscountSchema),
  items: z.array(LineItemSchema),
  fulfillments: z.array(FulfillmentSchema),
  payments: z.array(PaymentSchema),
  billing_address: AddressSchema.nullable(),
  shipping_address: AddressSchema.nullable(),
  gift_card: GiftCardSchema.nullable(),
  market: z.lazy(() => MarketSchema).nullable(),
});

export type Order = z.infer<typeof OrderSchema>;
