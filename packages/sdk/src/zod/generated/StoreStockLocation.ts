// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreStockLocationSchema = z.object({
  id: z.string(),
  state_abbr: z.string().nullable(),
  name: z.string(),
  address1: z.string().nullable(),
  city: z.string().nullable(),
  zipcode: z.string().nullable(),
  country_iso: z.string().nullable(),
  country_name: z.string().nullable(),
  state_text: z.string().nullable(),
});

export type StoreStockLocation = z.infer<typeof StoreStockLocationSchema>;
