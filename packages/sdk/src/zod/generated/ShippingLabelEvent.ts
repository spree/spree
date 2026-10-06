// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ShippingLabelEventSchema = z.object({
  id: z.string(),
  status: z.string(),
  carrier: z.string().nullable(),
  service: z.string().nullable(),
  tracking_number: z.string().nullable(),
  refunded_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  owner_id: z.string(),
  owner_type: z.string(),
});

export type ShippingLabelEvent = z.infer<typeof ShippingLabelEventSchema>;
