// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailDeliverySchema = z.object({
  id: z.string(),
  tracking_number: z.string(),
  carrier: z.string().nullable(),
  carrier_name: z.string().nullable(),
  service: z.string().nullable(),
  status: z.string(),
  tracking_url: z.string().nullable(),
  estimated_delivery_at: z.string().nullable(),
  delivered_at: z.string().nullable(),
});

export type EmailDelivery = z.infer<typeof EmailDeliverySchema>;
