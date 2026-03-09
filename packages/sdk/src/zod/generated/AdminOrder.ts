// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminAddressSchema } from './AdminAddress';
import { AdminAdjustmentSchema } from './AdminAdjustment';
import { AdminCustomerSchema } from './AdminCustomer';
import { AdminLineItemSchema } from './AdminLineItem';
import { AdminOrderPromotionSchema } from './AdminOrderPromotion';
import { AdminPaymentSchema } from './AdminPayment';
import { AdminPaymentMethodSchema } from './AdminPaymentMethod';
import { AdminReimbursementSchema } from './AdminReimbursement';
import { AdminReturnAuthorizationSchema } from './AdminReturnAuthorization';
import { AdminShipmentSchema } from './AdminShipment';

export const AdminOrderSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  number: z.string(),
  state: z.string(),
  checkout_steps: z.array(z.string()),
  token: z.string(),
  email: z.string().nullable(),
  special_instructions: z.string().nullable(),
  currency: z.string(),
  locale: z.string().nullable(),
  item_count: z.number(),
  state_lock_version: z.number(),
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
  order_promotions: z.array(AdminOrderPromotionSchema).optional(),
  line_items: z.array(z.lazy(() => AdminLineItemSchema)).optional(),
  shipments: z.array(z.lazy(() => AdminShipmentSchema)).optional(),
  payments: z.array(z.lazy(() => AdminPaymentSchema)).optional(),
  bill_address: AdminAddressSchema.nullable().optional(),
  ship_address: AdminAddressSchema.nullable().optional(),
  payment_methods: z.array(AdminPaymentMethodSchema).optional(),
  channel: z.string().nullable(),
  last_ip_address: z.string().nullable(),
  considered_risky: z.boolean(),
  confirmation_delivered: z.boolean(),
  store_owner_notification_delivered: z.boolean(),
  payment_total: z.string(),
  display_payment_total: z.string(),
  canceled_at: z.string().nullable(),
  approved_at: z.string().nullable(),
  internal_note: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  approver_id: z.string().nullable(),
  canceler_id: z.string().nullable(),
  created_by_id: z.string().nullable(),
  user_id: z.string().nullable(),
  user: z.lazy(() => AdminCustomerSchema).optional(),
  approver: z.lazy(() => AdminCustomerSchema).optional(),
  canceler: z.lazy(() => AdminCustomerSchema).optional(),
  created_by: z.lazy(() => AdminCustomerSchema).optional(),
  adjustments: z.array(z.lazy(() => AdminAdjustmentSchema)).optional(),
  return_authorizations: z.array(AdminReturnAuthorizationSchema).optional(),
  reimbursements: z.array(AdminReimbursementSchema).optional(),
});

export type AdminOrder = z.infer<typeof AdminOrderSchema>;
