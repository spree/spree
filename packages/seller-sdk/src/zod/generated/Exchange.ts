// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ExchangeLineItemSchema } from './ExchangeLineItem';
import { ReasonSchema } from './Reason';

export const ExchangeSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  memo: z.string().nullable(),
  cancelable: z.boolean(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  price_difference: z.string(),
  approved_at: z.string().nullable(),
  received_at: z.string().nullable(),
  fulfilled_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  reason: ReasonSchema.optional(),
  exchange_line_items: z.array(ExchangeLineItemSchema).optional(),
  stock_location_id: z.string().nullable(),
});

export type Exchange = z.infer<typeof ExchangeSchema>;
