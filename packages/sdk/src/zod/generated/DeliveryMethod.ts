// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliveryMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string().nullable(),
  fulfillment_type: z.string(),
  estimated_transit_business_days_min: z.number().nullable(),
  estimated_transit_business_days_max: z.number().nullable(),
});

export type DeliveryMethod = z.infer<typeof DeliveryMethodSchema>;
