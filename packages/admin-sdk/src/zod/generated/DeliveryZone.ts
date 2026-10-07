// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DeliveryZoneMemberSchema } from './DeliveryZoneMember';

export const DeliveryZoneSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  members: z.array(DeliveryZoneMemberSchema).optional(),
  created_at: z.string(),
  updated_at: z.string(),
  delivery_profile_id: z.string(),
  delivery_origin_group_id: z.string().nullable(),
  delivery_method_ids: z.array(z.string()),
});

export type DeliveryZone = z.infer<typeof DeliveryZoneSchema>;
