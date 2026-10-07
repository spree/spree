// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PurchaseOrderEventSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  ordered_at: z.string().nullable(),
  received_at: z.string().nullable(),
  closed_short_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  supplier_id: z.string().nullable(),
  destination_location_id: z.string().nullable(),
});

export type PurchaseOrderEvent = z.infer<typeof PurchaseOrderEventSchema>;
