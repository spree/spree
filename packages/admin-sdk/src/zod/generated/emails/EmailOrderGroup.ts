// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailAddressSchema } from './EmailAddress';
import { EmailAmountLineSchema } from './EmailAmountLine';
import { EmailFulfillmentGroupSchema } from './EmailFulfillmentGroup';
import { EmailLineItemSchema } from './EmailLineItem';
import { EmailPaymentSchema } from './EmailPayment';

export const EmailOrderGroupSchema = z.object({
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
  billing_address: EmailAddressSchema.nullable(),
  shipping_address: EmailAddressSchema.nullable(),
  payments: z.array(EmailPaymentSchema),
  customer_name: z.string(),
  total_minus_store_credits: z.string(),
  display_total_minus_store_credits: z.string(),
  items: z.array(EmailLineItemSchema),
  promotion_discounts: z.array(EmailAmountLineSchema),
  manual_discounts: z.array(EmailAmountLineSchema),
  fee_lines: z.array(EmailAmountLineSchema),
  po_number: z.string().nullable(),
  order_count: z.number(),
  fulfillment_groups: z.array(EmailFulfillmentGroupSchema),
  unfulfilled_items: z.array(EmailLineItemSchema),
  delivery_lines: z.array(EmailAmountLineSchema),
});

export type EmailOrderGroup = z.infer<typeof EmailOrderGroupSchema>;
