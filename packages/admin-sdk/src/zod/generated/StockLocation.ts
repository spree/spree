// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { SellerSchema } from './Seller';

export const StockLocationSchema = z.object({
  id: z.string(),
  name: z.string(),
  address1: z.string().nullable(),
  city: z.string().nullable(),
  zipcode: z.string().nullable(),
  country_code: z.string().nullable(),
  country_name: z.string().nullable(),
  state_code: z.string().nullable(),
  state_text: z.string().nullable(),
  pickup_ready_in_minutes: z.number().nullable(),
  pickup_instructions: z.string().nullable(),
  external_references: z.record(z.string(), z.string()),
  admin_name: z.string().nullable(),
  address2: z.string().nullable(),
  state_name: z.string().nullable(),
  phone: z.string().nullable(),
  company: z.string().nullable(),
  active: z.boolean(),
  default: z.boolean(),
  backorderable_default: z.boolean(),
  propagate_all_variants: z.boolean(),
  kind: z.string(),
  pickup_enabled: z.boolean(),
  pickup_stock_policy: z.string(),
  returns_enabled: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  seller_id: z.string().nullable(),
  seller_name: z.string().nullable(),
  seller: SellerSchema.optional(),
});

export type StockLocation = z.infer<typeof StockLocationSchema>;
