// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { PolicySchema } from './Policy';

export const ProfileSchema = z.object({
  id: z.string(),
  name: z.string(),
  slug: z.string(),
  about: z.string(),
  about_html: z.string(),
  logo_url: z.string().nullable(),
  square_logo_url: z.string().nullable(),
  cover_photo_url: z.string().nullable(),
  timezone: z.string().nullable(),
  status: z.string(),
  legal_name: z.string().nullable(),
  registration_number: z.string().nullable(),
  contact_email: z.string().nullable(),
  billing_email: z.string().nullable(),
  tax_remittance: z.string(),
  payouts_schedule_interval: z.string().nullable(),
  holiday_mode_until: z.string().nullable(),
  terms_accepted_at: z.string().nullable(),
  created_at: z.string(),
  minimum_payout_amount: z.string().nullable(),
  policies: z.array(PolicySchema).optional(),
  on_holiday: z.boolean(),
  sellable: z.boolean(),
  default_currency: z.string(),
  supported_currencies: z.array(z.string()),
  products_count: z.number(),
  billing_address: AddressSchema.optional(),
  returns_address: AddressSchema.optional(),
});

export type Profile = z.infer<typeof ProfileSchema>;
