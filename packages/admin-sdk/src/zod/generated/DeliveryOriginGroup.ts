// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliveryOriginGroupSchema = z.object({
  id: z.string(),
  name: z.string().nullable(),
  position: z.number().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  delivery_profile_id: z.string(),
  stock_location_ids: z.array(z.string()),
  delivery_zones_count: z.number(),
  delivery_methods_count: z.number(),
});

export type DeliveryOriginGroup = z.infer<typeof DeliveryOriginGroupSchema>;
