// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OrderChangeEventSchema = z.object({
  id: z.string(),
  status: z.string(),
  requested_at: z.string().nullable(),
  confirmed_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  order_id: z.string(),
  return_id: z.string().nullable(),
  exchange_id: z.string().nullable(),
  claim_id: z.string().nullable(),
});

export type OrderChangeEvent = z.infer<typeof OrderChangeEventSchema>;
