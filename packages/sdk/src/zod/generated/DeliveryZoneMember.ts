// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliveryZoneMemberSchema = z.object({
  id: z.string(),
  member_type: z.string(),
  postal_code_prefix: z.string().nullable(),
  postal_code_from: z.string().nullable(),
  postal_code_to: z.string().nullable(),
  country_iso: z.string().nullable(),
  state_abbr: z.string().nullable(),
  state_name: z.string().nullable(),
});

export type DeliveryZoneMember = z.infer<typeof DeliveryZoneMemberSchema>;
