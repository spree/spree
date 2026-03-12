// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { CartPromotionSchema } from './CartPromotion';
import { LineItemSchema } from './LineItem';
import { PaymentSchema } from './Payment';
import { PaymentMethodSchema } from './PaymentMethod';
import { ShipmentSchema } from './Shipment';

export const CartSchema = z.object({
  id: z.string(),
  number: z.string(),
  token: z.string(),
  email: z.string().nullable(),
  special_instructions: z.string().nullable(),
  currency: z.string(),
  locale: z.string().nullable(),
  item_count: z.number(),
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
  created_at: z.string(),
  updated_at: z.string(),
  current_step: z.string(),
  completed_steps: z.array(z.string()),
  requirements: z.array(z.object({ step: z.string(), field: z.string(), message: z.string() })),
  promotions: z.array(CartPromotionSchema),
  items: z.array(LineItemSchema),
  shipments: z.array(ShipmentSchema),
  payments: z.array(PaymentSchema),
  bill_address: AddressSchema.nullable(),
  ship_address: AddressSchema.nullable(),
  payment_methods: z.array(PaymentMethodSchema),
});

export type Cart = z.infer<typeof CartSchema>;
