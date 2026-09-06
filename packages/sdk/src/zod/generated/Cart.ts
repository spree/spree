// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { AppliedPromotionSchema } from './AppliedPromotion';
import { FeeSchema } from './Fee';
import { FulfillmentSchema } from './Fulfillment';
import { GiftCardSchema } from './GiftCard';
import { LineItemSchema } from './LineItem';
import { MarketSchema } from './Market';
import { PaymentSchema } from './Payment';
import { PaymentMethodSchema } from './PaymentMethod';

export const CartSchema = z.object({
  id: z.string(),
  market_id: z.string().nullable(),
  channel_id: z.string().nullable(),
  preferred_stock_location_id: z.string().nullable(),
  company_id: z.string().nullable(),
  company_name: z.string().nullable(),
  po_number_required: z.boolean(),
  po_document_filename: z.string().nullable(),
  po_document_byte_size: z.number().nullable(),
  number: z.string(),
  token: z.string(),
  email: z.string().nullable(),
  customer_note: z.string().nullable(),
  po_number: z.string().nullable(),
  currency: z.string(),
  locale: z.string().nullable(),
  total_quantity: z.number(),
  warnings: z.array(z.any()),
  coupon_code: z.string().nullable(),
  item_total: z.string().nullable(),
  display_item_total: z.string().nullable(),
  adjustment_total: z.string().nullable(),
  display_adjustment_total: z.string().nullable(),
  discount_total: z.string().nullable(),
  display_discount_total: z.string().nullable(),
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
  fee_total: z.string().nullable(),
  display_fee_total: z.string().nullable(),
  store_credit_total: z.string().nullable(),
  display_store_credit_total: z.string().nullable(),
  covered_by_store_credit: z.boolean(),
  current_step: z.string(),
  completed_steps: z.array(z.string()),
  requirements: z.array(z.object({ step: z.string(), field: z.string(), code: z.string(), message: z.string() })),
  order_minimum: z.number().nullable(),
  order_minimum_shortfall: z.number().nullable(),
  below_order_minimum: z.boolean().nullable(),
  payment_schedule: z.record(z.string(), z.unknown()).nullable(),
  freight_summary: z.record(z.string(), z.unknown()).nullable(),
  shipping_eq_billing_address: z.boolean(),
  discounts: z.array(AppliedPromotionSchema),
  fees: z.array(FeeSchema),
  items: z.array(LineItemSchema),
  fulfillments: z.array(FulfillmentSchema),
  payments: z.array(PaymentSchema),
  billing_address: AddressSchema.nullable(),
  shipping_address: AddressSchema.nullable(),
  payment_methods: z.array(PaymentMethodSchema),
  gift_card: GiftCardSchema.nullable(),
  market: z.lazy(() => MarketSchema).nullable(),
});

export type Cart = z.infer<typeof CartSchema>;
