// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ActorSchema } from './Actor';
import { DeliverySchema } from './Delivery';
import { OrderSchema } from './Order';
import { RefundSchema } from './Refund';
import { ReturnLineItemSchema } from './ReturnLineItem';
import { ReturnReasonSchema } from './ReturnReason';
import { ShippingLabelSchema } from './ShippingLabel';
import { StockLocationSchema } from './StockLocation';

export const ReturnSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  refund_total: z.string(),
  display_refund_total: z.string(),
  approved_at: z.string().nullable(),
  received_at: z.string().nullable(),
  refunded_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  reason: ReturnReasonSchema.optional(),
  return_line_items: z.array(ReturnLineItemSchema).optional(),
  memo: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  stock_location_id: z.string().nullable(),
  created_by_id: z.string().nullable(),
  created_by_type: z.string().nullable(),
  created_by: ActorSchema.optional(),
  refunded_total: z.string(),
  refundable_total: z.string(),
  order: z.lazy(() => OrderSchema).optional(),
  stock_location: StockLocationSchema.optional(),
  refunds: z.array(z.lazy(() => RefundSchema)).optional(),
  documents: z.array(z.object({ kind: z.string(), url: z.string() })),
  labels: z.array(ShippingLabelSchema),
  deliveries: z.array(DeliverySchema),
});

export type Return = z.infer<typeof ReturnSchema>;
