// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DeliveryMethodRuleSchema } from './DeliveryMethodRule';

export const DeliveryMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string().nullable(),
  estimated_transit_business_days_min: z.number().nullable(),
  estimated_transit_business_days_max: z.number().nullable(),
  digital: z.boolean(),
  pickup: z.boolean(),
  pickup_point: z.boolean(),
  admin_name: z.string().nullable(),
  storefront_visible: z.boolean(),
  tracking_url: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  rules: z.array(DeliveryMethodRuleSchema),
  editable: z.boolean(),
  delivery_profile_id: z.string().nullable(),
  delivery_zone_id: z.string().nullable(),
  calculator: z.object({ type: z.string(), preferences: z.record(z.string(), z.unknown()) }).nullable(),
});

export type DeliveryMethod = z.infer<typeof DeliveryMethodSchema>;
