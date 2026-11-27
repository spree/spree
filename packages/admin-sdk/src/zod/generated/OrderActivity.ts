// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ActorSchema } from './Actor';
import { OrderChangeSchema } from './OrderChange';

export const OrderActivitySchema = z.object({
  id: z.string(),
  kind: z.string(),
  category: z.string(),
  body: z.string().nullable(),
  details: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  order_change_id: z.string().nullable(),
  actor_id: z.string().nullable(),
  actor_type: z.string().nullable(),
  actor: ActorSchema.optional(),
  order_change: OrderChangeSchema.optional(),
});

export type OrderActivity = z.infer<typeof OrderActivitySchema>;
