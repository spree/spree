// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Return from '../../types/generated/Return';
import { ActorSchema } from './Actor';
import { CustomFieldSchema } from './CustomField';
import { DeliverySchema } from './Delivery';
import { OrderSchema } from './Order';
import { RefundSchema } from './Refund';
import { ReturnLineItemSchema } from './ReturnLineItem';
import { ReturnReasonSchema } from './ReturnReason';
import { ShippingLabelSchema } from './ShippingLabel';
import { StockLocationSchema } from './StockLocation';

export const ReturnSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  refund_total: z.string(),
  refund_tax_total: z.string(),
  approved_at: z.string().nullable(),
  received_at: z.string().nullable(),
  refunded_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  reason: ReturnReasonSchema.optional(),
  return_line_items: z.array(ReturnLineItemSchema).optional(),
  custom_fields: z.array(CustomFieldSchema).optional(),
  external_references: z.record(z.string(), z.string()),
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
  get order() { return OrderSchema.optional(); },
  stock_location: StockLocationSchema.optional(),
  get refunds() { return z.array(RefundSchema).optional(); },
  documents: z.array(z.object({ kind: z.string(), url: z.string() })),
  labels: z.array(ShippingLabelSchema),
  deliveries: z.array(DeliverySchema),
}) as unknown as z.ZodObject<{
  id: z.ZodType<Return['id']>;
  number: z.ZodType<Return['number']>;
  status: z.ZodType<Return['status']>;
  order_id: z.ZodType<Return['order_id']>;
  reason_id: z.ZodType<Return['reason_id']>;
  refund_total: z.ZodType<Return['refund_total']>;
  refund_tax_total: z.ZodType<Return['refund_tax_total']>;
  approved_at: z.ZodType<Return['approved_at']>;
  received_at: z.ZodType<Return['received_at']>;
  refunded_at: z.ZodType<Return['refunded_at']>;
  canceled_at: z.ZodType<Return['canceled_at']>;
  reason: z.ZodOptional<z.ZodType<Exclude<Return['reason'], undefined>>>;
  return_line_items: z.ZodOptional<z.ZodType<Exclude<Return['return_line_items'], undefined>>>;
  custom_fields: z.ZodOptional<z.ZodType<Exclude<Return['custom_fields'], undefined>>>;
  external_references: z.ZodType<Return['external_references']>;
  memo: z.ZodType<Return['memo']>;
  metadata: z.ZodType<Return['metadata']>;
  created_at: z.ZodType<Return['created_at']>;
  updated_at: z.ZodType<Return['updated_at']>;
  stock_location_id: z.ZodType<Return['stock_location_id']>;
  created_by_id: z.ZodType<Return['created_by_id']>;
  created_by_type: z.ZodType<Return['created_by_type']>;
  created_by: z.ZodOptional<z.ZodType<Exclude<Return['created_by'], undefined>>>;
  refunded_total: z.ZodType<Return['refunded_total']>;
  refundable_total: z.ZodType<Return['refundable_total']>;
  order: z.ZodOptional<z.ZodType<Exclude<Return['order'], undefined>>>;
  stock_location: z.ZodOptional<z.ZodType<Exclude<Return['stock_location'], undefined>>>;
  refunds: z.ZodOptional<z.ZodType<Exclude<Return['refunds'], undefined>>>;
  documents: z.ZodType<Return['documents']>;
  labels: z.ZodType<Return['labels']>;
  deliveries: z.ZodType<Return['deliveries']>;
}>;

export type { Return };
