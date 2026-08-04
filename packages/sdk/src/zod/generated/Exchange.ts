// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ExchangeLineItemSchema } from './ExchangeLineItem';

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
  exchange_line_items: z.array(ExchangeLineItemSchema).optional(),
});

export type Exchange = z.infer<typeof ExchangeSchema>;
