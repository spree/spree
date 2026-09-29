// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ActorSchema } from './Actor';
import { AddressSchema } from './Address';
import { AppliedPromotionSchema } from './AppliedPromotion';
import { CartSchema } from './Cart';
import { ChannelSchema } from './Channel';
import { ClaimSchema } from './Claim';
import { CustomerSchema } from './Customer';
import { ExchangeSchema } from './Exchange';
import { FreightSummarySchema } from './FreightSummary';
import { FulfillmentSchema } from './Fulfillment';
import { GiftCardSchema } from './GiftCard';
import { LineItemSchema } from './LineItem';
import { MarketSchema } from './Market';
import { OrderCancellationReasonSchema } from './OrderCancellationReason';
import { PaymentSchema } from './Payment';
import { PaymentMethodSchema } from './PaymentMethod';
import { PaymentSplitSchema } from './PaymentSplit';
import { ReturnSchema } from './Return';
import { SellerSchema } from './Seller';
import { StockLocationSchema } from './StockLocation';

export const OrderSchema = z.object({
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
  gift_card_total: z.string(),
  display_gift_card_total: z.string(),
  amount_due: z.string(),
  display_amount_due: z.string(),
  delivery_total: z.string(),
  display_delivery_total: z.string(),
  fee_total: z.string(),
  display_fee_total: z.string(),
  store_credit_total: z.string(),
  display_store_credit_total: z.string(),
  covered_by_store_credit: z.boolean(),
  items: z.array(LineItemSchema).optional(),
  get fulfillments() { return z.array(FulfillmentSchema).optional(); },
  get payments() { return z.array(PaymentSchema).optional(); },
  billing_address: AddressSchema.nullable().optional(),
  shipping_address: AddressSchema.nullable().optional(),
  get gift_card() { return GiftCardSchema.nullable(); },
  get market() { return MarketSchema.nullable(); },
  external_references: z.record(z.string(), z.string()),
  status: z.string(),
  last_ip_address: z.string().nullable(),
  considered_risky: z.boolean(),
  confirmation_delivered: z.boolean(),
  store_owner_notification_delivered: z.boolean(),
  payment_total: z.string(),
  display_payment_total: z.string(),
  metadata: z.record(z.string(), z.unknown()),
  cancel_note: z.string().nullable(),
  commission_amount_total: z.string(),
  display_commission_amount_total: z.string(),
  commission_tax_total: z.string(),
  display_commission_tax_total: z.string(),
  commission_total: z.string(),
  display_commission_total: z.string(),
  canceled_at: z.string().nullable(),
  approved_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  preferred_stock_location_id: z.string().nullable(),
  po_document_url: z.string().nullable(),
  seller_id: z.string().nullable(),
  seller: SellerSchema.optional(),
  order_group_id: z.string().nullable(),
  tags: z.array(z.string()),
  internal_note: z.string().nullable(),
  internal_note_html: z.string().nullable(),
  approver_id: z.string().nullable(),
  approver_type: z.string().nullable(),
  approver: ActorSchema.optional(),
  canceler_id: z.string().nullable(),
  canceler_type: z.string().nullable(),
  canceler: ActorSchema.optional(),
  created_by_id: z.string().nullable(),
  created_by_type: z.string().nullable(),
  created_by: ActorSchema.optional(),
  cancel_reason_id: z.string().nullable(),
  cancel_reason_name: z.string().nullable(),
  customer_id: z.string().nullable(),
  applied_promotions: z.array(AppliedPromotionSchema).optional(),
  payment_splits: z.array(PaymentSplitSchema).optional(),
  cart: CartSchema.optional(),
  channel: ChannelSchema.optional(),
  preferred_stock_location: StockLocationSchema.optional(),
  payment_methods: z.array(PaymentMethodSchema).optional(),
  get customer() { return CustomerSchema.optional(); },
  cancel_reason: OrderCancellationReasonSchema.optional(),
  get returns() { return z.array(ReturnSchema).optional(); },
  get exchanges() { return z.array(ExchangeSchema).optional(); },
  get claims() { return z.array(ClaimSchema).optional(); },
  freight_summary: FreightSummarySchema.nullable(),
});

export type Order = z.infer<typeof OrderSchema>;
