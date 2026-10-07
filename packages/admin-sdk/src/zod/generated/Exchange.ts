// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
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
  display_price_difference: z.string(),
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
});

export type Exchange = z.infer<typeof ExchangeSchema>;
