// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Exchange from '../../types/generated/Exchange';
import { ActorSchema } from './Actor';
import { ExchangeLineItemSchema } from './ExchangeLineItem';
import { OrderSchema } from './Order';
import { RefundSchema } from './Refund';
import { ReturnReasonSchema } from './ReturnReason';
import { StockLocationSchema } from './StockLocation';

export const ExchangeSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  price_difference: z.string(),
  approved_at: z.string().nullable(),
  received_at: z.string().nullable(),
  fulfilled_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  reason: ReturnReasonSchema.optional(),
  exchange_line_items: z.array(ExchangeLineItemSchema).optional(),
  memo: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  stock_location_id: z.string().nullable(),
  created_by_id: z.string().nullable(),
  created_by_type: z.string().nullable(),
  created_by: ActorSchema.optional(),
  get order() { return OrderSchema.optional(); },
  stock_location: StockLocationSchema.optional(),
  get refunds() { return z.array(RefundSchema).optional(); },
}) as unknown as z.ZodObject<{
  id: z.ZodType<Exchange['id']>;
  number: z.ZodType<Exchange['number']>;
  status: z.ZodType<Exchange['status']>;
  order_id: z.ZodType<Exchange['order_id']>;
  reason_id: z.ZodType<Exchange['reason_id']>;
  price_difference: z.ZodType<Exchange['price_difference']>;
  approved_at: z.ZodType<Exchange['approved_at']>;
  received_at: z.ZodType<Exchange['received_at']>;
  fulfilled_at: z.ZodType<Exchange['fulfilled_at']>;
  canceled_at: z.ZodType<Exchange['canceled_at']>;
  reason: z.ZodOptional<z.ZodType<Exclude<Exchange['reason'], undefined>>>;
  exchange_line_items: z.ZodOptional<z.ZodType<Exclude<Exchange['exchange_line_items'], undefined>>>;
  memo: z.ZodType<Exchange['memo']>;
  metadata: z.ZodType<Exchange['metadata']>;
  created_at: z.ZodType<Exchange['created_at']>;
  updated_at: z.ZodType<Exchange['updated_at']>;
  stock_location_id: z.ZodType<Exchange['stock_location_id']>;
  created_by_id: z.ZodType<Exchange['created_by_id']>;
  created_by_type: z.ZodType<Exchange['created_by_type']>;
  created_by: z.ZodOptional<z.ZodType<Exclude<Exchange['created_by'], undefined>>>;
  order: z.ZodOptional<z.ZodType<Exclude<Exchange['order'], undefined>>>;
  stock_location: z.ZodOptional<z.ZodType<Exclude<Exchange['stock_location'], undefined>>>;
  refunds: z.ZodOptional<z.ZodType<Exclude<Exchange['refunds'], undefined>>>;
}>;

export type { Exchange };
