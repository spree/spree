// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';

export const SellerSchema = z.object({
  id: z.string(),
  name: z.string(),
  slug: z.string(),
  about: z.string(),
  about_html: z.string(),
  logo_url: z.string().nullable(),
  square_logo_url: z.string().nullable(),
  cover_photo_url: z.string().nullable(),
  status: z.string(),
  contact_email: z.string().nullable(),
  billing_email: z.string().nullable(),
  tax_remittance: z.string(),
  payouts_schedule_interval: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  holiday_mode_until: z.string().nullable(),
  terms_accepted_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  deleted_at: z.string().nullable(),
  minimum_payout_amount: z.string().nullable(),
  on_holiday: z.boolean(),
  sellable: z.boolean(),
  products_count: z.number(),
  users_count: z.number(),
  onboarding_progress: z.object({ done: z.number(), total: z.number() }),
  onboarding_complete: z.boolean(),
  legal_name: z.string().nullable(),
  registration_number: z.string().nullable(),
  billing_address: AddressSchema.optional(),
  returns_address: AddressSchema.optional(),
});

export type Seller = z.infer<typeof SellerSchema>;
