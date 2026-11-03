// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Cart from '../../types/generated/Cart';
import { AddressSchema } from './Address';
import { AppliedPromotionSchema } from './AppliedPromotion';
import { FreightSummarySchema } from './FreightSummary';
import { LineItemSchema } from './LineItem';
import { MarketSchema } from './Market';

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
  token: z.string(),
  email: z.string().nullable(),
  customer_note: z.string().nullable(),
  po_number: z.string().nullable(),
  currency: z.string(),
  locale: z.string().nullable(),
  total_quantity: z.number(),
  warnings: z.array(z.object({ code: z.string(), message: z.string(), line_item_id: z.string().optional(), variant_id: z.string().optional(), item_index: z.number().optional() })),
  coupon_code: z.string().nullable(),
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
  adjustment_total: z.string().nullable(),
  current_step: z.string(),
  completed_steps: z.array(z.string()),
  requirements: z.array(z.object({ step: z.string(), field: z.string(), code: z.string(), message: z.string() })),
  order_minimum: z.string().nullable(),
  order_minimum_shortfall: z.string().nullable(),
  below_order_minimum: z.boolean().nullable(),
  freight_summary: FreightSummarySchema.nullable(),
  shipping_eq_billing_address: z.boolean(),
  get items() { return z.array(LineItemSchema); },
  billing_address: AddressSchema.nullable(),
  shipping_address: AddressSchema.nullable(),
  get market() { return MarketSchema.nullable(); },
  completed_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  applied_promotions: z.array(AppliedPromotionSchema),
}) as unknown as z.ZodObject<{
  id: z.ZodType<Cart['id']>;
  market_id: z.ZodType<Cart['market_id']>;
  channel_id: z.ZodType<Cart['channel_id']>;
  preferred_stock_location_id: z.ZodType<Cart['preferred_stock_location_id']>;
  company_id: z.ZodType<Cart['company_id']>;
  company_name: z.ZodType<Cart['company_name']>;
  po_number_required: z.ZodType<Cart['po_number_required']>;
  po_document_filename: z.ZodType<Cart['po_document_filename']>;
  po_document_byte_size: z.ZodType<Cart['po_document_byte_size']>;
  token: z.ZodType<Cart['token']>;
  email: z.ZodType<Cart['email']>;
  customer_note: z.ZodType<Cart['customer_note']>;
  po_number: z.ZodType<Cart['po_number']>;
  currency: z.ZodType<Cart['currency']>;
  locale: z.ZodType<Cart['locale']>;
  total_quantity: z.ZodType<Cart['total_quantity']>;
  warnings: z.ZodType<Cart['warnings']>;
  coupon_code: z.ZodType<Cart['coupon_code']>;
  item_total: z.ZodType<Cart['item_total']>;
  discount_total: z.ZodType<Cart['discount_total']>;
  tax_total: z.ZodType<Cart['tax_total']>;
  included_tax_total: z.ZodType<Cart['included_tax_total']>;
  additional_tax_total: z.ZodType<Cart['additional_tax_total']>;
  delivery_total: z.ZodType<Cart['delivery_total']>;
  fee_total: z.ZodType<Cart['fee_total']>;
  gift_card_total: z.ZodType<Cart['gift_card_total']>;
  store_credit_total: z.ZodType<Cart['store_credit_total']>;
  total: z.ZodType<Cart['total']>;
  amount_due: z.ZodType<Cart['amount_due']>;
  covered_by_store_credit: z.ZodType<Cart['covered_by_store_credit']>;
  adjustment_total: z.ZodType<Cart['adjustment_total']>;
  current_step: z.ZodType<Cart['current_step']>;
  completed_steps: z.ZodType<Cart['completed_steps']>;
  requirements: z.ZodType<Cart['requirements']>;
  order_minimum: z.ZodType<Cart['order_minimum']>;
  order_minimum_shortfall: z.ZodType<Cart['order_minimum_shortfall']>;
  below_order_minimum: z.ZodType<Cart['below_order_minimum']>;
  freight_summary: z.ZodType<Cart['freight_summary']>;
  shipping_eq_billing_address: z.ZodType<Cart['shipping_eq_billing_address']>;
  items: z.ZodType<Cart['items']>;
  billing_address: z.ZodType<Cart['billing_address']>;
  shipping_address: z.ZodType<Cart['shipping_address']>;
  market: z.ZodType<Cart['market']>;
  completed_at: z.ZodType<Cart['completed_at']>;
  created_at: z.ZodType<Cart['created_at']>;
  updated_at: z.ZodType<Cart['updated_at']>;
  applied_promotions: z.ZodType<Cart['applied_promotions']>;
}>;

export type { Cart };
