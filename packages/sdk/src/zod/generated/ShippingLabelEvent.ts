// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ShippingLabelEventSchema = z.object({
  id: z.string(),
  source: z.string(),
  status: z.string(),
  carrier: z.string().nullable(),
  service: z.string().nullable(),
  tracking_number: z.string().nullable(),
  currency: z.string().nullable(),
  format: z.string().nullable(),
  external_id: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  refunded_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  owner_id: z.string(),
  owner_type: z.string(),
  carrier_name: z.string().nullable(),
  cost: z.string(),
  display_cost: z.string(),
  integration_id: z.string().nullable(),
  file_pending: z.boolean(),
  download_url: z.string().nullable(),
});

export type ShippingLabelEvent = z.infer<typeof ShippingLabelEventSchema>;
