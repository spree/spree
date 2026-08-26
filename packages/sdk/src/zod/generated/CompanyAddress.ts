// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CompanyAddressSchema = z.object({
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
  country_code: z.string(),
  state_text: z.string().nullable(),
  state_code: z.string().nullable(),
  quick_checkout: z.boolean(),
  is_default_billing: z.boolean(),
  is_default_shipping: z.boolean(),
  state_abbr: z.string().nullable(),
  country_iso: z.string(),
  state_name: z.string().nullable(),
  label: z.string().nullable(),
  company_id: z.string(),
  default_billing: z.boolean(),
  default_shipping: z.boolean(),
});

export type CompanyAddress = z.infer<typeof CompanyAddressSchema>;
