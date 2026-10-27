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
  shipping_eq_billing_address: z.boolean(),
  cart_id: z.string().nullable(),
  channel_id: z.string().nullable(),
  company_id: z.string().nullable(),
  company_name: z.string().nullable(),
  po_document_filename: z.string().nullable(),
  po_document_byte_size: z.number().nullable(),
  pricing_access: z.string().nullable(),
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
  discount_total: z.string().nullable(),
  tax_total: z.string().nullable(),
  included_tax_total: z.string().nullable(),
  additional_tax_total: z.string().nullable(),
  delivery_total: z.string().nullable(),
  fee_total: z.string().nullable(),
  gift_card_total: z.string().nullable(),
  store_credit_total: z.string().nullable(),
  total: z.string().nullable(),
  amount_due: z.string().nullable(),
  covered_by_store_credit: z.boolean(),
  payments: z.array(EmailPaymentSchema),
  adjustment_total: z.string().nullable(),
  discounts: z.array(EmailAppliedPromotionSchema),
  fees: z.array(EmailFeeSchema),
  items: z.array(EmailLineItemSchema),
  fulfillments: z.array(EmailFulfillmentSchema),
  billing_address: EmailAddressSchema.nullable(),
  shipping_address: EmailAddressSchema.nullable(),
  gift_card: EmailGiftCardSchema.nullable(),
  market: EmailMarketSchema.nullable(),
  customer_name: z.string(),
  total_minus_store_credits: z.string(),
  promotion_discounts: z.array(EmailAmountLineSchema),
  manual_discounts: z.array(EmailAmountLineSchema),
  fee_lines: z.array(EmailAmountLineSchema),
  delivery_lines: z.array(EmailAmountLineSchema),
});

export type EmailOrder = z.infer<typeof EmailOrderSchema>;
