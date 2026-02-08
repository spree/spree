// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreAddressSchema = z.object({
  id: z.string(),
  firstname: z.string().nullable(),
  lastname: z.string().nullable(),
  full_name: z.string(),
  address1: z.string().nullable(),
  address2: z.string().nullable(),
  city: z.string().nullable(),
  zipcode: z.string().nullable(),
  phone: z.string().nullable(),
  company: z.string().nullable(),
  country_name: z.string(),
  country_iso: z.string(),
  state_text: z.string().nullable(),
  state_abbr: z.string().nullable(),
  state_name: z.string().nullable(),
});

export type StoreAddress = z.infer<typeof StoreAddressSchema>;
