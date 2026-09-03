// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliverySchema = z.object({
  id: z.string(),
  tracking_number: z.string(),
  tracking_url: z.string().nullable(),
  carrier: z.string().nullable(),
  carrier_name: z.string().nullable(),
  service: z.string().nullable(),
  status: z.string(),
  estimated_delivery_at: z.string().nullable(),
  delivered_at: z.string().nullable(),
});

export type Delivery = z.infer<typeof DeliverySchema>;
