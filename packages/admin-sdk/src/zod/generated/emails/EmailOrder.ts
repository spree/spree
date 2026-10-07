// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailAddressSchema } from './EmailAddress';
import { EmailAmountLineSchema } from './EmailAmountLine';
import { EmailAppliedPromotionSchema } from './EmailAppliedPromotion';
import { EmailFeeSchema } from './EmailFee';
import { EmailFulfillmentSchema } from './EmailFulfillment';
import { EmailGiftCardSchema } from './EmailGiftCard';
import { EmailLineItemSchema } from './EmailLineItem';
import { EmailMarketSchema } from './EmailMarket';
import { EmailPaymentSchema } from './EmailPayment';

export const EmailOrderSchema = z.object({
  id: z.string(),
  market_id: z.string().nullable(),
  withdrawal_period_ends_at: z.string().nullable(),
  within_withdrawal_period: z.boolean(),
  cart_id: z.string().nullable(),
  channel_id: z.string().nullable(),
  company_id: z.string().nullable(),
  company_name: z.string().nullable(),
  po_document_filename: z.string().nullable(),
  po_document_byte_size: z.number().nullable(),
  number: z.string(),
  email: z.string(),
  customer_note: z.string().nullable(),
  po_number: z.string().nullable(),
  currency: z.string(),
  locale: z.string().nullable(),
  total_quantity: z.number(),
  coupon_code: z.string().nullable(),
  fulfillment_status: z.string().nullable(),
  payment_status: z.string().nullable(),
  completed_at: z.string().nullable(),
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
  discounts: z.array(EmailAppliedPromotionSchema),
  fees: z.array(EmailFeeSchema),
  items: z.array(EmailLineItemSchema),
  fulfillments: z.array(EmailFulfillmentSchema),
  payments: z.array(EmailPaymentSchema),
  billing_address: EmailAddressSchema.nullable(),
  shipping_address: EmailAddressSchema.nullable(),
  gift_card: EmailGiftCardSchema.nullable(),
  market: EmailMarketSchema.nullable(),
  customer_name: z.string(),
  display_total_minus_store_credits: z.string(),
  promotion_discounts: z.array(EmailAmountLineSchema),
  manual_discounts: z.array(EmailAmountLineSchema),
  fee_lines: z.array(EmailAmountLineSchema),
  delivery_lines: z.array(EmailAmountLineSchema),
});

export type EmailOrder = z.infer<typeof EmailOrderSchema>;
