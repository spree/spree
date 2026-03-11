// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { LineItemSchema } from './LineItem';
import { OrderPromotionSchema } from './OrderPromotion';
import { PaymentSchema } from './Payment';
import { ShipmentSchema } from './Shipment';

export const OrderSchema = z.object({
  id: z.string(),
  number: z.string(),
  email: z.string(),
  special_instructions: z.string().nullable(),
  currency: z.string(),
  locale: z.string().nullable(),
  item_count: z.number(),
  shipment_state: z.string().nullable(),
  payment_state: z.string().nullable(),
  item_total: z.string(),
  display_item_total: z.string(),
  ship_total: z.string(),
  display_ship_total: z.string(),
  adjustment_total: z.string(),
  display_adjustment_total: z.string(),
  promo_total: z.string(),
  display_promo_total: z.string(),
  tax_total: z.string(),
  display_tax_total: z.string(),
  included_tax_total: z.string(),
  display_included_tax_total: z.string(),
  additional_tax_total: z.string(),
  display_additional_tax_total: z.string(),
  total: z.string(),
  display_total: z.string(),
  completed_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  order_promotions: z.array(OrderPromotionSchema),
  line_items: z.array(LineItemSchema),
  shipments: z.array(ShipmentSchema),
  payments: z.array(PaymentSchema),
  bill_address: AddressSchema.nullable(),
  ship_address: AddressSchema.nullable(),
});

export type Order = z.infer<typeof OrderSchema>;
