// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OrderLookupRequestedEventSchema = z.object({
  id: z.string(),
  email: z.string(),
  number: z.string(),
  order_token: z.string(),
  store_id: z.string().nullable(),
});

export type OrderLookupRequestedEvent = z.infer<typeof OrderLookupRequestedEventSchema>;
