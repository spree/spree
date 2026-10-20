// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DeliveryMethodRuleSchema } from './DeliveryMethodRule';
import { DeliveryMethodServiceSchema } from './DeliveryMethodService';

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
  available_to_sellers: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  deleted_at: z.string(),
  markup_flat: z.string().nullable(),
  markup_percent: z.string().nullable(),
  seller_id: z.string().nullable(),
  seller_name: z.string().nullable(),
  services: z.array(DeliveryMethodServiceSchema),
  rules: z.array(DeliveryMethodRuleSchema),
  tax_category_id: z.string().nullable(),
  delivery_profile_id: z.string(),
  delivery_origin_group_id: z.string().nullable(),
  delivery_zone_id: z.string().nullable(),
  stock_location_ids: z.array(z.string()),
  fulfillment_provider: z.string(),
  pickup_point_provider: z.string().nullable(),
  rate_provider: z.string().nullable(),
  calculator: z.any().nullable(),
});

export type DeliveryMethod = z.infer<typeof DeliveryMethodSchema>;
