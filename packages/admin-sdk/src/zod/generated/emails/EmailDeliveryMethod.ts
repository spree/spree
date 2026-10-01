// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailDeliveryMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string().nullable(),
  estimated_transit_business_days_min: z.number().nullable(),
  estimated_transit_business_days_max: z.number().nullable(),
  digital: z.boolean(),
  pickup: z.boolean(),
  pickup_point: z.boolean(),
});

export type EmailDeliveryMethod = z.infer<typeof EmailDeliveryMethodSchema>;
