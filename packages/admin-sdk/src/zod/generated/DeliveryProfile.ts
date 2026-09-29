// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliveryProfileSchema = z.object({
  id: z.string(),
  name: z.string(),
  default: z.boolean(),
  position: z.number().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  kind: z.string(),
  digital: z.boolean(),
  offers_pickup: z.boolean(),
  offers_shipping: z.boolean(),
  stock_location_ids: z.array(z.string()),
  origin_groups: z.array(z.object({ id: z.string(), name: z.string().nullable(), position: z.number().nullable(), stock_location_ids: z.array(z.string()) })),
  products_count: z.number(),
  delivery_methods_count: z.number(),
  delivery_zones_count: z.number(),
});

export type DeliveryProfile = z.infer<typeof DeliveryProfileSchema>;
