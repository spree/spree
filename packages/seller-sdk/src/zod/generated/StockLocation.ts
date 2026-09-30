// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

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
  address2: z.string().nullable(),
  state_name: z.string().nullable(),
  phone: z.string().nullable(),
  company: z.string().nullable(),
  active: z.boolean(),
  default: z.boolean(),
  kind: z.string(),
  returns_enabled: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type StockLocation = z.infer<typeof StockLocationSchema>;
