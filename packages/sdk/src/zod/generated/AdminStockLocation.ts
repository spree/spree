// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminStockLocationSchema = z.object({
  id: z.string(),
  state_abbr: z.string().nullable(),
  name: z.string(),
  address1: z.string().nullable(),
  city: z.string().nullable(),
  zipcode: z.string().nullable(),
  country_iso: z.string().nullable(),
  country_name: z.string().nullable(),
  state_text: z.string().nullable(),
  active: z.boolean(),
  default: z.boolean(),
  backorderable_default: z.boolean(),
  propagate_all_variants: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type AdminStockLocation = z.infer<typeof AdminStockLocationSchema>;
