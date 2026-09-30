// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SupplierSchema = z.object({
  id: z.string(),
  name: z.string(),
  contact_name: z.string().nullable(),
  email: z.string().nullable(),
  phone: z.string().nullable(),
  notes: z.string().nullable(),
  address1: z.string().nullable(),
  address2: z.string().nullable(),
  city: z.string().nullable(),
  state_name: z.string().nullable(),
  state_code: z.string().nullable(),
  country_code: z.string().nullable(),
  postal_code: z.string().nullable(),
  purchase_orders_count: z.number(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  deleted_at: z.string().nullable(),
  can_be_deleted: z.boolean(),
});

export type Supplier = z.infer<typeof SupplierSchema>;
