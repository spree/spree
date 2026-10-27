// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Order from '../../types/generated/Order';
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
  item_total: z.string(),
  discount_total: z.string(),
  tax_total: z.string(),
  included_tax_total: z.string(),
  additional_tax_total: z.string(),
  delivery_total: z.string(),
  fee_total: z.string(),
  gift_card_total: z.string(),
  store_credit_total: z.string(),
  total: z.string(),
  amount_due: z.string(),
  covered_by_store_credit: z.boolean(),
  get payments() { return z.array(PaymentSchema).optional(); },
  adjustment_total: z.string(),
  items: z.array(LineItemSchema).optional(),
  get fulfillments() { return z.array(FulfillmentSchema).optional(); },
  billing_address: AddressSchema.nullable().optional(),
  shipping_address: AddressSchema.nullable().optional(),
  get gift_card() { return GiftCardSchema.nullable(); },
  get market() { return MarketSchema.nullable(); },
  external_references: z.record(z.string(), z.string()),
  status: z.string(),
  last_ip_address: z.string().nullable(),
  considered_risky: z.boolean(),
  confirmation_delivered: z.boolean(),
  store_owner_notification_delivered: z.boolean().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  cancel_note: z.string().nullable(),
  canceled_at: z.string().nullable(),
  approved_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  payment_total: z.string(),
  commission_amount_total: z.string(),
  commission_tax_total: z.string(),
  commission_total: z.string(),
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
}) as unknown as z.ZodObject<{
  id: z.ZodType<Order['id']>;
  market_id: z.ZodType<Order['market_id']>;
  withdrawal_period_ends_at: z.ZodType<Order['withdrawal_period_ends_at']>;
  within_withdrawal_period: z.ZodType<Order['within_withdrawal_period']>;
  shipping_eq_billing_address: z.ZodType<Order['shipping_eq_billing_address']>;
  cart_id: z.ZodType<Order['cart_id']>;
  channel_id: z.ZodType<Order['channel_id']>;
  company_id: z.ZodType<Order['company_id']>;
  company_name: z.ZodType<Order['company_name']>;
  po_document_filename: z.ZodType<Order['po_document_filename']>;
  po_document_byte_size: z.ZodType<Order['po_document_byte_size']>;
  pricing_access: z.ZodType<Order['pricing_access']>;
  number: z.ZodType<Order['number']>;
  email: z.ZodType<Order['email']>;
  customer_note: z.ZodType<Order['customer_note']>;
  po_number: z.ZodType<Order['po_number']>;
  currency: z.ZodType<Order['currency']>;
  locale: z.ZodType<Order['locale']>;
  total_quantity: z.ZodType<Order['total_quantity']>;
  coupon_code: z.ZodType<Order['coupon_code']>;
  fulfillment_status: z.ZodType<Order['fulfillment_status']>;
  payment_status: z.ZodType<Order['payment_status']>;
  completed_at: z.ZodType<Order['completed_at']>;
  item_total: z.ZodType<Order['item_total']>;
  discount_total: z.ZodType<Order['discount_total']>;
  tax_total: z.ZodType<Order['tax_total']>;
  included_tax_total: z.ZodType<Order['included_tax_total']>;
  additional_tax_total: z.ZodType<Order['additional_tax_total']>;
  delivery_total: z.ZodType<Order['delivery_total']>;
  fee_total: z.ZodType<Order['fee_total']>;
  gift_card_total: z.ZodType<Order['gift_card_total']>;
  store_credit_total: z.ZodType<Order['store_credit_total']>;
  total: z.ZodType<Order['total']>;
  amount_due: z.ZodType<Order['amount_due']>;
  covered_by_store_credit: z.ZodType<Order['covered_by_store_credit']>;
  payments: z.ZodOptional<z.ZodType<Exclude<Order['payments'], undefined>>>;
  adjustment_total: z.ZodType<Order['adjustment_total']>;
  items: z.ZodOptional<z.ZodType<Exclude<Order['items'], undefined>>>;
  fulfillments: z.ZodOptional<z.ZodType<Exclude<Order['fulfillments'], undefined>>>;
  billing_address: z.ZodOptional<z.ZodType<Exclude<Order['billing_address'], undefined>>>;
  shipping_address: z.ZodOptional<z.ZodType<Exclude<Order['shipping_address'], undefined>>>;
  gift_card: z.ZodType<Order['gift_card']>;
  market: z.ZodType<Order['market']>;
  external_references: z.ZodType<Order['external_references']>;
  status: z.ZodType<Order['status']>;
  last_ip_address: z.ZodType<Order['last_ip_address']>;
  considered_risky: z.ZodType<Order['considered_risky']>;
  confirmation_delivered: z.ZodType<Order['confirmation_delivered']>;
  store_owner_notification_delivered: z.ZodType<Order['store_owner_notification_delivered']>;
  metadata: z.ZodType<Order['metadata']>;
  cancel_note: z.ZodType<Order['cancel_note']>;
  canceled_at: z.ZodType<Order['canceled_at']>;
  approved_at: z.ZodType<Order['approved_at']>;
  created_at: z.ZodType<Order['created_at']>;
  updated_at: z.ZodType<Order['updated_at']>;
  payment_total: z.ZodType<Order['payment_total']>;
  commission_amount_total: z.ZodType<Order['commission_amount_total']>;
  commission_tax_total: z.ZodType<Order['commission_tax_total']>;
  commission_total: z.ZodType<Order['commission_total']>;
  preferred_stock_location_id: z.ZodType<Order['preferred_stock_location_id']>;
  po_document_url: z.ZodType<Order['po_document_url']>;
  seller_id: z.ZodType<Order['seller_id']>;
  seller: z.ZodOptional<z.ZodType<Exclude<Order['seller'], undefined>>>;
  order_group_id: z.ZodType<Order['order_group_id']>;
  tags: z.ZodType<Order['tags']>;
  internal_note: z.ZodType<Order['internal_note']>;
  internal_note_html: z.ZodType<Order['internal_note_html']>;
  approver_id: z.ZodType<Order['approver_id']>;
  approver_type: z.ZodType<Order['approver_type']>;
  approver: z.ZodOptional<z.ZodType<Exclude<Order['approver'], undefined>>>;
  canceler_id: z.ZodType<Order['canceler_id']>;
  canceler_type: z.ZodType<Order['canceler_type']>;
  canceler: z.ZodOptional<z.ZodType<Exclude<Order['canceler'], undefined>>>;
  created_by_id: z.ZodType<Order['created_by_id']>;
  created_by_type: z.ZodType<Order['created_by_type']>;
  created_by: z.ZodOptional<z.ZodType<Exclude<Order['created_by'], undefined>>>;
  cancel_reason_id: z.ZodType<Order['cancel_reason_id']>;
  cancel_reason_name: z.ZodType<Order['cancel_reason_name']>;
  customer_id: z.ZodType<Order['customer_id']>;
  applied_promotions: z.ZodOptional<z.ZodType<Exclude<Order['applied_promotions'], undefined>>>;
  payment_splits: z.ZodOptional<z.ZodType<Exclude<Order['payment_splits'], undefined>>>;
  cart: z.ZodOptional<z.ZodType<Exclude<Order['cart'], undefined>>>;
  channel: z.ZodOptional<z.ZodType<Exclude<Order['channel'], undefined>>>;
  preferred_stock_location: z.ZodOptional<z.ZodType<Exclude<Order['preferred_stock_location'], undefined>>>;
  payment_methods: z.ZodOptional<z.ZodType<Exclude<Order['payment_methods'], undefined>>>;
  customer: z.ZodOptional<z.ZodType<Exclude<Order['customer'], undefined>>>;
  cancel_reason: z.ZodOptional<z.ZodType<Exclude<Order['cancel_reason'], undefined>>>;
  returns: z.ZodOptional<z.ZodType<Exclude<Order['returns'], undefined>>>;
  exchanges: z.ZodOptional<z.ZodType<Exclude<Order['exchanges'], undefined>>>;
  claims: z.ZodOptional<z.ZodType<Exclude<Order['claims'], undefined>>>;
  freight_summary: z.ZodType<Order['freight_summary']>;
}>;

export type { Order };
