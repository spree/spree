// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminCustomerSchema } from './AdminCustomer';
import { AdminLineItemSchema } from './AdminLineItem';
import { StoreAddressSchema } from './StoreAddress';
import { StoreOrderPromotionSchema } from './StoreOrderPromotion';
import { StorePaymentSchema } from './StorePayment';
import { StorePaymentMethodSchema } from './StorePaymentMethod';
import { StoreShipmentSchema } from './StoreShipment';

export const AdminOrderSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  number: z.string(),
  state: z.string(),
  token: z.string(),
  email: z.string().nullable(),
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
  order_promotions: z.array(StoreOrderPromotionSchema),
  line_items: z.array(AdminLineItemSchema),
  shipments: z.array(StoreShipmentSchema),
  payments: z.array(StorePaymentSchema),
  bill_address: StoreAddressSchema.nullable(),
  ship_address: StoreAddressSchema.nullable(),
  payment_methods: z.array(StorePaymentMethodSchema),
  channel: z.string().nullable(),
  last_ip_address: z.string().nullable(),
  considered_risky: z.boolean(),
  confirmation_delivered: z.boolean(),
  store_owner_notification_delivered: z.boolean(),
  internal_note: z.string().nullable(),
  approver_id: z.string().nullable(),
  canceled_at: z.string().nullable(),
  approved_at: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  canceler_id: z.string().nullable(),
  created_by_id: z.string().nullable(),
  user: z.lazy(() => AdminCustomerSchema).optional(),
});

export type AdminOrder = z.infer<typeof AdminOrderSchema>;
