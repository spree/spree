// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DeliveryZoneMemberSchema } from './DeliveryZoneMember';

export const DeliveryZoneSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  members: z.array(DeliveryZoneMemberSchema).optional(),
});

export type DeliveryZone = z.infer<typeof DeliveryZoneSchema>;
