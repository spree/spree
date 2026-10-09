// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliveryRateSchema = z.object({
  id: z.string(),
  name: z.string(),
  selected: z.boolean(),
  cost: z.string(),
  total: z.string(),
  carrier: z.string().nullable(),
  service_level: z.string().nullable(),
  estimated_delivery_date: z.string().nullable(),
  unpriced: z.boolean(),
});

export type DeliveryRate = z.infer<typeof DeliveryRateSchema>;
