// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ChannelSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string(),
  active: z.boolean(),
  default: z.boolean(),
  storefront_access: z.string(),
  guest_checkout: z.boolean(),
  preferred_order_routing_strategy: z.string().nullable(),
  preferred_storefront_access: z.string().nullable(),
  preferred_guest_checkout: z.boolean().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  stock_location_ids: z.array(z.string()),
  default_catalog_id: z.string().nullable(),
});

export type Channel = z.infer<typeof ChannelSchema>;
