// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ChannelSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string(),
  active: z.boolean(),
  default: z.boolean(),
  storefront_access: z.string().nullable(),
  guest_checkout: z.boolean().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  order_routing_strategy: z.string().nullable(),
  stock_location_ids: z.array(z.string()),
  default_catalog_id: z.string().nullable(),
});

export type Channel = z.infer<typeof ChannelSchema>;
