// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AddressSchema = z.object({
  id: z.string(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  full_name: z.string(),
  address1: z.string().nullable(),
  address2: z.string().nullable(),
  postal_code: z.string().nullable(),
  city: z.string().nullable(),
  phone: z.string().nullable(),
  company: z.string().nullable(),
  country_name: z.string(),
  country_iso: z.string(),
  state_text: z.string().nullable(),
  state_abbr: z.string().nullable(),
  quick_checkout: z.boolean(),
  is_default_billing: z.boolean(),
  is_default_shipping: z.boolean(),
  state_name: z.string().nullable(),
});

export type Address = z.infer<typeof AddressSchema>;
