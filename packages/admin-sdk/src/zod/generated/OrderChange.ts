// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ActorSchema } from './Actor';
import { OrderChangeActionSchema } from './OrderChangeAction';

export const OrderChangeSchema = z.object({
  id: z.string(),
  status: z.string(),
  metadata: z.record(z.string(), z.unknown()),
  requested_at: z.string().nullable(),
  confirmed_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  order_id: z.string(),
  return_id: z.string().nullable(),
  exchange_id: z.string().nullable(),
  claim_id: z.string().nullable(),
  requested_by_id: z.string().nullable(),
  requested_by_type: z.string().nullable(),
  requested_by: ActorSchema.optional(),
  actions: z.array(OrderChangeActionSchema),
});

export type OrderChange = z.infer<typeof OrderChangeSchema>;
